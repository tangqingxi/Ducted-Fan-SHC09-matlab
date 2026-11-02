# SHC09 visual model

`SHC09.glb` is copied from the modified Hawkeye fork used by the DuctedFan project:

- Source: https://github.com/mengchaoheng/Hawkeye/blob/df/models/SHC09.glb
- Hawkeye: https://github.com/mengchaoheng/Hawkeye (BSD-3-Clause)
- Format: binary glTF 2.0, one mesh, no materials/textures (1.37 MB)
- VIZ-App uses a minimal GLB parser and splits the six 60°-spaced control
  surfaces from the body by connectivity.

The model is a tail-sitter: nose +Y and duct -Y in the GLB are rotated +90°
about X so the nose is body -Z (up) and the duct is body +Z (down).
