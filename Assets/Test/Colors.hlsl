#ifndef COLORS_INCLUDED
#define COLORS_INCLUDED

// From Builtin cginc ====================================
inline float Builtin_GammaToLinearSpaceExact (float value)
{
    if (value <= 0.04045F)
        return value / 12.92F;
    else if (value < 1.0F)
        return pow((value + 0.055F)/1.055F, 2.4F);
    else
        return pow(value, 2.2F);
}

inline half3 Builtin_GammaToLinearSpace (half3 sRGB)
{
    // Approximate version from http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
    return sRGB * (sRGB * (sRGB * 0.305306011h + 0.682171111h) + 0.012522878h);

    // Precise version, useful for debugging.
    //return half3(GammaToLinearSpaceExact(sRGB.r), GammaToLinearSpaceExact(sRGB.g), GammaToLinearSpaceExact(sRGB.b));
}

inline float Builtin_LinearToGammaSpaceExact (float value)
{
    if (value <= 0.0F)
        return 0.0F;
    else if (value <= 0.0031308F)
        return 12.92F * value;
    else if (value < 1.0F)
        return 1.055F * pow(value, 0.4166667F) - 0.055F;
    else
        return pow(value, 0.45454545F);
}

inline half3 Builtin_LinearToGammaSpace (half3 linRGB)
{
    linRGB = max(linRGB, half3(0.h, 0.h, 0.h));
    // An almost-perfect approximation from http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
    return max(1.055h * pow(linRGB, 0.416666667h) - 0.055h, 0.h);

    // Exact version, useful for debugging.
    //return half3(LinearToGammaSpaceExact(linRGB.r), LinearToGammaSpaceExact(linRGB.g), LinearToGammaSpaceExact(linRGB.b));
}

// From bgolus  ====================================
// https://discussions.unity.com/t/linear-vs-gamma-color-space-for-ui-font-rendering/745834/16
half3 LinearToGammaSpace3(half3 col)
{
    col.r = Builtin_LinearToGammaSpaceExact(col.r);
    col.g = Builtin_LinearToGammaSpaceExact(col.g);
    col.b = Builtin_LinearToGammaSpaceExact(col.b);
    return col;
}

half3 GammaToLinearSpace3(half3 col)
{
    col.r = Builtin_GammaToLinearSpaceExact(col.r);
    col.g = Builtin_GammaToLinearSpaceExact(col.g);
    col.b = Builtin_GammaToLinearSpaceExact(col.b);
    return col;
}

// SG ColorConversion functions ====================================
// https://docs.unity3d.com/Packages/com.unity.shadergraph@14.0/manual/Colorspace-Conversion-Node.html
float3 Unity_ColorspaceConversion_RGB_HSV_float(float3 In)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 P = lerp(float4(In.bg, K.wz), float4(In.gb, K.xy), step(In.b, In.g));
    float4 Q = lerp(float4(P.xyw, In.r), float4(In.r, P.yzx), step(P.x, In.r));
    float D = Q.x - min(Q.w, Q.y);
    float  E = 1e-10;
    return float3(abs(Q.z + (Q.w - Q.y)/(6.0 * D + E)), D / (Q.x + E), Q.x);
}

float3 Unity_ColorspaceConversion_HSV_RGB_float(float3 In)
{
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 P = abs(frac(In.xxx + K.xyz) * 6.0 - K.www);
    return In.z * lerp(K.xxx, saturate(P - K.xxx), In.y);
}

float3 Unity_ColorspaceConversion_RGB_Linear_float(float3 In)
{
    float3 linearRGBLo = In / 12.92;;
    float3 linearRGBHi = pow(max(abs((In + 0.055) / 1.055), 1.192092896e-07), float3(2.4, 2.4, 2.4));
    return float3(In <= 0.04045) ? linearRGBLo : linearRGBHi;
}

float3 Unity_ColorspaceConversion_Linear_RGB_float(float3 In)
{
    float3 sRGBLo = In * 12.92;
    float3 sRGBHi = (pow(max(abs(In), 1.192092896e-07), float3(1.0 / 2.4, 1.0 / 2.4, 1.0 / 2.4)) * 1.055) - 0.055;
    return float3(In <= 0.0031308) ? sRGBLo : sRGBHi;
}

float3 Unity_ColorspaceConversion_Linear_HSV_float(float3 In)
{
    float3 sRGBLo = In * 12.92;
    float3 sRGBHi = (pow(max(abs(In), 1.192092896e-07), float3(1.0 / 2.4, 1.0 / 2.4, 1.0 / 2.4)) * 1.055) - 0.055;
    float3 Linear = float3(In <= 0.0031308) ? sRGBLo : sRGBHi;
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 P = lerp(float4(Linear.bg, K.wz), float4(Linear.gb, K.xy), step(Linear.b, Linear.g));
    float4 Q = lerp(float4(P.xyw, Linear.r), float4(Linear.r, P.yzx), step(P.x, Linear.r));
    float D = Q.x - min(Q.w, Q.y);
    float  E = 1e-10;
    return float3(abs(Q.z + (Q.w - Q.y)/(6.0 * D + E)), D / (Q.x + E), Q.x);
}

float3 Unity_ColorspaceConversion_HSV_Linear_float(float3 In)
{
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 P = abs(frac(In.xxx + K.xyz) * 6.0 - K.www);
    float3 RGB = In.z * lerp(K.xxx, saturate(P - K.xxx), In.y);
    float3 linearRGBLo = RGB / 12.92;
    float3 linearRGBHi = pow(max(abs((RGB + 0.055) / 1.055), 1.192092896e-07), float3(2.4, 2.4, 2.4));
    return float3(RGB <= 0.04045) ? linearRGBLo : linearRGBHi;
}

#endif //COLORS_INCLUDED
