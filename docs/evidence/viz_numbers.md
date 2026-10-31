# VIZ 汇总数字（生成物）

> 本文件由 `viz/tools/summarize_study.py` 生成，不要手改；数值来自各 study 的
> `summary.csv` / `comparability.csv` / `status.csv`，状态字符串原样引用。

## M0 / lite / s1 — `task` window

- 方法覆盖：**5/5**（5 个方法齐全）
- comparability：`stress`（原样引用 comparability.csv，非本工具计算）
- 窗口：`summary.csv` 的 `window` 列；本表不重采样、不排序、不打分。

| method | saturation_percent | attitude_peak_deg | position_peak_m | estimated_attitude_rmse_deg | estimated_position_rmse_m | run_status |
|---|---|---|---|---|---|---|
| DA_NS | 0 | 5.45182 | 0.469231 | 1.40416 | 0.365329 | completed |
| WLS | 0 | 5.45182 | 0.469231 | 1.40416 | 0.365329 | completed |
| DCA | 1.92134 | 5.46334 | 0.468761 | 1.40337 | 0.365338 | completed |
| PCA_STATIC | 0 | 5.45182 | 0.469231 | 1.40416 | 0.365329 | completed |
| PCA_PREDICTIVE | 2.19153 | 5.46969 | 0.468859 | 1.4045 | 0.365344 | completed |

<details><summary>来源</summary>

- `E:\Ducted-Fan-SHC09-matlab\results\allocation_comparison_research_3seeds\summary.csv` sha256=`30dc26a538a5730595baf00d2c0b63750ad19728c9922fda86bfb9e0853ac33e`
- `E:\Ducted-Fan-SHC09-matlab\results\allocation_comparison_research_3seeds\comparability.csv` sha256=`9ed70279b355a384a29486d1932043aa18cba77913e087572a34fc6df082e3ea`
- `E:\Ducted-Fan-SHC09-matlab\results\allocation_comparison_research_3seeds\status.csv` sha256=`aa59d90fbcf66a1fa7e4e3e97187e65c648b2812b34ed0883d36a3c37b955d8e`
- viz repo git sha `7a80f7a2ddc5bf9bb6a3238d54e4f462712d3c77`
- generated_at `2026-10-31T12:51:37Z`

</details>

## M4 / lite / s1 — `task` window

- 方法覆盖：**5/5**（5 个方法齐全）
- comparability：`stress`（原样引用 comparability.csv，非本工具计算）
- 窗口：`summary.csv` 的 `window` 列；本表不重采样、不排序、不打分。

| method | load_fraction | saturation_percent | attitude_peak_deg | position_peak_m | estimated_attitude_rmse_deg | estimated_position_rmse_m | run_status |
|---|---|---|---|---|---|---|---|
| DA_NS | 0.4 | 0 | 5.50637 | 0.469265 | 1.40172 | 0.365336 | completed |
| DA_NS | 0.5 | 0 | 5.68469 | 0.469222 | 1.40435 | 0.365319 | completed |
| DA_NS | 0.6 | 83.5785 | 59.3215 | 0.486327 | 1.71975 | 0.357471 | completed |
| WLS | 0.4 | 0 | 5.50637 | 0.469265 | 1.40172 | 0.365336 | completed |
| WLS | 0.5 | 0 | 5.68469 | 0.469222 | 1.40435 | 0.365319 | completed |
| WLS | 0.6 | 96.1273 | 49.598 | 4.3615 | 6.66541 | 0.529475 | completed |
| DCA | 0.4 | 0.330231 | 5.46242 | 0.468977 | 1.4031 | 0.365349 | completed |
| DCA | 0.5 | 2.10147 | 5.48382 | 0.468952 | 1.40486 | 0.365339 | completed |
| DCA | 0.6 | 65.0856 | 20.7992 | 0.45964 | 1.44446 | 0.363898 | completed |
| PCA_STATIC | 0.4 | 0 | 5.50637 | 0.469265 | 1.40172 | 0.365336 | completed |
| PCA_STATIC | 0.5 | 0 | 5.68469 | 0.469222 | 1.40435 | 0.365319 | completed |
| PCA_STATIC | 0.6 | 94.1759 | 44.8348 | 1.15476 | 3.73255 | 0.388801 | completed |
| PCA_PREDICTIVE | 0.4 | 0.780546 | 5.5376 | 0.469967 | 1.40396 | 0.365341 | completed |
| PCA_PREDICTIVE | 0.5 | 2.55179 | 5.57175 | 0.469559 | 1.40786 | 0.365366 | completed |
| PCA_PREDICTIVE | 0.6 | 74.9625 | 10.4776 | 0.468324 | 1.93803 | 0.367513 | completed |

M4 的 load_fraction=0.4/0.5/0.6 三行全部列出，供对照；不挑选、不排序。早期按 800 Hz command_rad 帧统计的 39.1%（DCA）口径与冻结定义（PWM 事件 + 1e-5 deg 容差）不同，已由本表替代（DCA 行见 load=0.6）。

<details><summary>来源</summary>

- `E:\Ducted-Fan-SHC09-matlab\results\m4_load_sweep_research_seed1\summary.csv` sha256=`bdf7af6383e059ab5c13395b07755375fc7700902efa566ce0b5e2b094828194`
- `E:\Ducted-Fan-SHC09-matlab\results\m4_load_sweep_research_seed1\comparability.csv` sha256=`fbaa57d5f60d24dab58f7e63120fba279d3c74649b4454f6f10e086464edeb5f`
- `E:\Ducted-Fan-SHC09-matlab\results\m4_load_sweep_research_seed1\status.csv` sha256=`de593cb7338ac15c55018f9ee3160ce2f2268193d253e9de46bc2e8115962f78`
- viz repo git sha `7a80f7a2ddc5bf9bb6a3238d54e4f462712d3c77`
- generated_at `2026-10-31T12:51:37Z`

</details>
