#include <EKF/ekf.h>
#include <geo_lookup/geo_mag_declination.h>
#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <sstream>
#include <string>
#include <memory>
#include <limits>
#include <cmath>

// 仅桥接原始传感器和官方EKF输出；该程序不接收真值姿态、真值位置或控制目标。
int main()
{
    std::unique_ptr<Ekf> ekf;
    std::string time_mode = "A";
    float gps_delay_ms = 0.0f;
    map_projection_reference_s world{};
    double origin_altitude = 488.0;
    float hacc = 0.5f, vacc = 0.8f, sacc = 0.1f;
    std::string line;
    while (std::getline(std::cin, line)) {
        std::istringstream input(line);
        std::string command;
        input >> command;
        if (command == "CLOSE") { break; }
        if (command == "INIT") {
            double latitude, longitude, altitude;
            float gps_delay, baro_delay, mag_delay;
            input >> latitude >> longitude >> altitude >> gps_delay >> baro_delay >> mag_delay >> hacc >> vacc >> sacc;
            if (!input) { std::cout << "ERROR init_arguments" << std::endl; return 2; }
            if (const char *hacc_text = std::getenv("ECL_HACC")) { hacc = float(std::atof(hacc_text)); }
            origin_altitude = altitude;
            map_projection_init_timestamped(&world, latitude, longitude, 1000000);
            if (const char *mode = std::getenv("ECL_TIME_MODE")) { time_mode = mode; }
            gps_delay_ms = gps_delay;
            ekf.reset(new Ekf());
            auto *p = ekf->getParamHandle();
            p->gps_delay_ms = (time_mode == "A") ? gps_delay : 0.0f;
            p->baro_delay_ms = baro_delay; p->mag_delay_ms = mag_delay;
            p->fusion_mode = MASK_USE_GPS;
            std::cerr << "TIME_MODE=" << time_mode << " gps_delay_ms=" << p->gps_delay_ms
                      << " hacc=" << hacc << std::endl;
            // 保留官方默认的对准、健康检查和融合策略，仅给出传感器接口已知延迟。
            ekf->init(1000000);
            const float declination = get_mag_declination_radians(latitude, longitude);
            const float inclination = get_mag_inclination_radians(latitude, longitude);
            const float strength = get_mag_strength_gauss(latitude, longitude);
            std::printf("B %.9g %.9g %.9g\n", strength*std::cos(inclination)*std::cos(declination),
                        strength*std::cos(inclination)*std::sin(declination), strength*std::sin(inclination));
            std::fflush(stdout);
            continue;
        }
        if (command != "STEP" || !ekf) { std::cout << "ERROR command" << std::endl; return 2; }
        unsigned long long timestamp;
        double dt;
        int in_air, has_gps, has_baro, has_mag;
        double gyro[3], accel[3], gps_position[3], gps_velocity[3], baro_altitude, magnetic[3];
        input >> timestamp >> dt >> in_air;
        for (auto &v : gyro) { input >> v; }
        for (auto &v : accel) { input >> v; }
        input >> has_gps;
        for (auto &v : gps_position) { input >> v; }
        for (auto &v : gps_velocity) { input >> v; }
        input >> has_baro >> baro_altitude >> has_mag;
        for (auto &v : magnetic) { input >> v; }
        if (!input) { std::cout << "ERROR step_arguments" << std::endl; return 2; }
        imuSample imu{};
        imu.time_us = timestamp; imu.delta_ang_dt = dt; imu.delta_vel_dt = dt;
        for (int i = 0; i < 3; ++i) { imu.delta_ang(i) = gyro[i]*dt; imu.delta_vel(i) = accel[i]*dt; }
        ekf->setIMUData(imu);
        ekf->set_in_air_status(in_air != 0);
        ekf->set_is_fixed_wing(false);
        uint64_t gps_timestamp = timestamp;
        if (has_gps) {
            double latitude, longitude;
            map_projection_reproject(&world, gps_position[0], gps_position[1], &latitude, &longitude);
            gps_message gps{};
            if (time_mode == "B") {
                gps_timestamp = (timestamp > uint64_t(gps_delay_ms * 1000.0f)) ? timestamp - uint64_t(gps_delay_ms * 1000.0f) : 0;
            } else if (time_mode == "C") {
                gps_timestamp = timestamp + uint64_t(gps_delay_ms * 1000.0f);
            }
            gps.time_usec = gps_timestamp;
            gps.lat = std::llround(latitude*1e7); gps.lon = std::llround(longitude*1e7);
            gps.alt = std::llround((origin_altitude-gps_position[2])*1000.0);
            gps.yaw = std::numeric_limits<float>::quiet_NaN(); gps.yaw_offset = 0;
            gps.fix_type = 3; gps.eph = hacc; gps.epv = vacc; gps.sacc = sacc;
            for (int i = 0; i < 3; ++i) { gps.vel_ned(i) = gps_velocity[i]; }
            gps.vel_m_s = gps.vel_ned.norm(); gps.vel_ned_valid = true; gps.nsats = 12; gps.pdop = 1;
            ekf->setGpsData(gps);
        }
        if (has_baro) { baroSample baro{}; baro.time_us = timestamp; baro.hgt = baro_altitude; ekf->setBaroData(baro); }
        if (has_mag) {
            magSample mag{}; mag.time_us = timestamp;
            for (int i = 0; i < 3; ++i) { mag.mag(i) = magnetic[i]; }
            ekf->setMagData(mag);
        }
        const bool updated = ekf->update();
        const auto local_position = ekf->getPosition();
        auto position = local_position;
        const auto quaternion = ekf->getQuaternion(); const auto velocity = ekf->getVelocity();
        const auto gyro_bias = ekf->getGyroBias(); const auto accel_bias = ekf->getAccelBias();
        const auto variance = ekf->getPositionVariance();
        uint64_t origin_time = 0; double latitude = 0, longitude = 0; float altitude = 0;
        const bool origin_valid = ekf->getEkfGlobalOrigin(origin_time, latitude, longitude, altitude);
        float offset_n = 0.0f, offset_e = 0.0f;
        if (origin_valid) {
            map_projection_project(&world, latitude, longitude, &offset_n, &offset_e);
            position(0) += offset_n; position(1) += offset_e; position(2) += origin_altitude-altitude;
        }
        // 诊断 stderr：不改 stdout 协议，不改 EKF 数值。
        if (has_gps) {
            float hvel[2]{}, hpos[2]{}, vvel = 0, vpos = 0;
            float hvel_r = 0, vvel_r = 0, hpos_r = 0, vpos_r = 0;
            ekf->getGpsVelPosInnov(hvel, vvel, hpos, vpos);
            ekf->getGpsVelPosInnovRatio(hvel_r, vvel_r, hpos_r, vpos_r);
            uint16_t checks = 0; ekf->get_gps_check_status(&checks);
            const auto flags = ekf->control_status_flags();
            float sp[3]{}, sv[3]{}, op[3]{}, ov[3]{}, gp[3]{}, gv[3]{}, iv[3]{}, ir[4]{};
            uint64_t gst = 0, lhp = 0, lhv = 0;
            bool ga = false, ha = false;
            uint8_t pnc = 0, vnc = 0;
            ekf->getDebugSnapshot(sp, sv, op, ov, gp, gv, iv, ir, gst, lhp, lhv, ga, ha, pnc, vnc);
            std::cerr << "DBG t=" << timestamp << " mode=" << time_mode
                      << " gps_time=" << gps_timestamp << " gps_sample_time=" << gst
                      << " last_hpos=" << lhp << " last_hvel=" << lhv
                      << " gps=" << gps_position[0] << "," << gps_position[1] << "," << gps_position[2]
                      << " local=" << local_position(0) << "," << local_position(1) << "," << local_position(2)
                      << " origin=" << offset_n << "," << offset_e
                      << " out=" << position(0) << "," << position(1) << "," << position(2)
                      << " vel=" << velocity(0) << "," << velocity(1) << "," << velocity(2)
                      << " state_pos=" << sp[0] << "," << sp[1] << "," << sp[2]
                      << " state_vel=" << sv[0] << "," << sv[1] << "," << sv[2]
                      << " out_pos=" << op[0] << "," << op[1] << "," << op[2]
                      << " out_vel=" << ov[0] << "," << ov[1] << "," << ov[2]
                      << " gps_sample_pos=" << gp[0] << "," << gp[1] << "," << gp[2]
                      << " gps_sample_vel=" << gv[0] << "," << gv[1] << "," << gv[2]
                      << " innov=" << iv[0] << "," << iv[1] << "," << iv[2]
                      << " origin_valid=" << int(origin_valid)
                      << " gpsflag=" << int(ga) << " hgtflag=" << int(ha) << " checks=" << checks
                      << " hpos_ratio=" << hpos_r << " vpos_ratio=" << vpos_r
                      << " hvel_ratio=" << hvel_r << " hpos_innov=" << hpos[0] << "," << hpos[1]
                      << " reset_posne=" << int(pnc) << " reset_velne=" << int(vnc)
                      << std::endl;
        }
        std::printf("R");
        for (int i = 0; i < 4; ++i) { std::printf(" %.9g", quaternion(i)); }
        for (int i = 0; i < 3; ++i) { std::printf(" %.9g", position(i)); }
        for (int i = 0; i < 3; ++i) { std::printf(" %.9g", velocity(i)); }
        for (int i = 0; i < 3; ++i) { std::printf(" %.9g", gyro_bias(i)); }
        for (int i = 0; i < 3; ++i) { std::printf(" %.9g", accel_bias(i)); }
        for (int i = 0; i < 3; ++i) { std::printf(" %.9g", variance(i)); }
        const auto flags = ekf->control_status_flags();
        std::printf(" %d %d %d %d %d %u %d\n", ekf->attitude_valid(), ekf->local_position_is_valid(),
                    flags.yaw_align, flags.gps, origin_valid, unsigned(ekf->fault_status().value), updated);
        std::fflush(stdout);
    }
    return 0;
}
