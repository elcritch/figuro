import std/math
import pixie, vmath, chroma
import nimsimd/hassimd, nimsimd/neon

when defined(release):
  {.push checks: off.}

when not compiles(vabsq_f32(float32x4(0.0))):
  func vabsq_f32*(a: float32x4): float32x4 {.header: "arm_neon.h".}
when not compiles(vsqrtq_f32(float32x4(0.0))):
  func vsqrtq_f32*(a: float32x4): float32x4 {.header: "arm_neon.h".}
when not compiles(vcvtq_u32_f32(float32x4(0.0))):
  func vcvtq_u32_f32*(a: float32x4): uint32x4 {.header: "arm_neon.h".}

proc sdRoundedBoxSimd*(px, py: float32x4, bx, by: float32, r: Vec4): float32x4 {.inline.} =
  ## SIMD version of signed distance function for rounded box
  ## Processes 4 pixels at once
  
  let
    zero = vmovq_n_f32(0.0)
    rx_xy = vmovq_n_f32(r.x) # top-right radius
    ry_xy = vmovq_n_f32(r.y) # bottom-right radius
    rz_zw = vmovq_n_f32(r.z) # bottom-left radius
    rw_zw = vmovq_n_f32(r.w) # top-left radius
    bx_vec = vmovq_n_f32(bx)
    by_vec = vmovq_n_f32(by)
  
  # Select corner radius based on quadrant
  # cornerRadius.xy = if p.x > 0.0: r.xy else: r.zw
  let
    px_pos = vcgtq_f32(px, zero) # px > 0
    py_pos = vcgtq_f32(py, zero) # py > 0
  
  # Select x-based radius (r.x/r.y if px > 0, else r.z/r.w)
  let radius_x = vbslq_f32(px_pos, rx_xy, rz_zw)
  let radius_y = vbslq_f32(px_pos, ry_xy, rw_zw)
  
  # cornerRadius.x = if p.y > 0.0: cornerRadius.x else: cornerRadius.y
  let corner_radius = vbslq_f32(py_pos, radius_x, radius_y)
  
  # Calculate q = abs(p) - b + vec2(cornerRadius.x, cornerRadius.x)
  let
    abs_px = vabsq_f32(px)
    abs_py = vabsq_f32(py)
    qx = vaddq_f32(vsubq_f32(abs_px, bx_vec), corner_radius)
    qy = vaddq_f32(vsubq_f32(abs_py, by_vec), corner_radius)
  
  # max(q, 0.0)
  let
    max_qx = vmaxq_f32(qx, zero)
    max_qy = vmaxq_f32(qy, zero)
  
  # length(max(q, 0.0)) = sqrt(max_qx^2 + max_qy^2)
  let
    max_qx_sq = vmulq_f32(max_qx, max_qx)
    max_qy_sq = vmulq_f32(max_qy, max_qy)
    length_sq = vaddq_f32(max_qx_sq, max_qy_sq)
  
  # sqrt approximation using vsqrtq_f32 (available in ARMv8)
  when defined(arm64) or defined(aarch64):
    let length_vec = vsqrtq_f32(length_sq)
  else:
    # Fallback for older ARM processors
    var length_array: array[4, float32]
    vst1q_f32(length_array[0].addr, length_sq)
    for i in 0..3:
      length_array[i] = sqrt(length_array[i])
    let length_vec = vld1q_f32(length_array[0].addr)
  
  # min(max(q.x, q.y), 0.0) + length - cornerRadius
  let
    max_q = vmaxq_f32(qx, qy)
    min_max_q = vminq_f32(max_q, zero)
  
  result = vaddq_f32(vsubq_f32(vaddq_f32(min_max_q, length_vec), corner_radius), zero)

type
  SDFMode* = enum
    sdfModeFeather
    sdfModeClip

proc signedRoundedBoxFeatherNeon*(
    image: Image,
    center: Vec2,
    b: Vec2,
    r: Vec4,
    pos: ColorRGBA, neg: ColorRGBA,
    mode: SDFMode = sdfModeFeather
) {.simd.} =
  ## NEON SIMD optimized version of signedRoundedBoxFeather
  ## Processes pixels in chunks of 4 with padding for remaining pixels
  ## clip: if true, use solid colors without feathering based on SDF sign
  
  let
    pos_rgbx = pos.rgbx()
    neg_rgbx = neg.rgbx()
    center_x = center.x
    center_y = center.y
    b_x = b.x
    b_y = b.y
    four_vec = vmovq_n_f32(4.0)
    offset_vec = vmovq_n_f32(127.0)
    zero_vec = vmovq_n_f32(0.0)
    f255_vec = vmovq_n_f32(255.0)
  
  for y in 0 ..< image.height:
    let
      py_scalar = y.float32 - center_y
      py_vec = vmovq_n_f32(py_scalar)
      row_start = image.dataIndex(0, y)
    
    var x = 0
    
    # Process all pixels in chunks of 4, with padding for the last chunk
    while x < image.width:
      # Calculate how many pixels we actually need to process in this chunk
      let remainingPixels = min(4, image.width - x)
      
      # Calculate px for up to 4 pixels, padding with the last valid pixel
      var px_array: array[4, float32]
      for i in 0..3:
        let actualX = if i < remainingPixels: x + i else: x + remainingPixels - 1
        px_array[i] = actualX.float32 - center_x
      
      let px_vec = vld1q_f32(px_array[0].addr)
      
      # Calculate signed distances for 4 pixels
      let sd_vec = sdRoundedBoxSimd(px_vec, py_vec, b_x, b_y, r)
      
      # Extract individual values for color selection
      var sd_array: array[4, float32]
      vst1q_f32(sd_array[0].addr, sd_vec)
      
      case mode:
      of sdfModeClip:
        # Clipped mode: use solid colors based on SDF sign
        for i in 0 ..< remainingPixels:
          let
            sd = sd_array[i]
            final_color = if sd < 0.0: pos_rgbx else: neg_rgbx
            idx = row_start + x + i
          
          image.data[idx] = final_color

      of sdfModeFeather:
        # Feathered mode: calculate alpha values using SIMD
        # Calculate alpha values: uint8(max(0.0, min(255, (4*sd) + 127)))
        let
          scaled_sd = vmulq_f32(sd_vec, four_vec)
          alpha_float = vaddq_f32(scaled_sd, offset_vec)
          alpha_clamped_low = vmaxq_f32(alpha_float, zero_vec)
          alpha_clamped = vminq_f32(alpha_clamped_low, f255_vec)
        
        # Convert to uint8
        let alpha_u32 = vcvtq_u32_f32(alpha_clamped)
        var alpha_array: array[4, uint32]
        vst1q_u32(alpha_array[0].addr, alpha_u32)
        
        # Process only the actual pixels (not the padded ones)
        for i in 0 ..< remainingPixels:
          let
            sd = sd_array[i]
            base_color = if sd < 0.0: pos_rgbx else: neg_rgbx
            alpha = alpha_array[i].uint8
            idx = row_start + x + i
          
          var final_color = base_color
          final_color.a = alpha
          image.data[idx] = final_color
      
      x += remainingPixels

when defined(release):
  {.pop.}
