#ifndef URP_SHADER_INCLUDE_LYX_LIBRARY_FUNCTION
#define URP_SHADER_INCLUDE_LYX_LIBRARY_FUNCTION

#define FLOAT_HALF_VECTOR1_INPUT1(Name, Input, Function) \
float Name(float Input) {Function} \
float2 Name(float2 Input) {Function} \
float3 Name(float3 Input) {Function} \
float4 Name(float4 Input) {Function} \
half Name(half Input) {Function} \
half2 Name(half2 Input) {Function} \
half3 Name(half3 Input) {Function} \
half4 Name(half4 Input) {Function} \

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

float P(float input, float n) {n = n * 1.4427f + 1.4427f; return exp2(input * n - n);}
float2 P(float2 input, float n) {n = n * 1.4427f + 1.4427f; return exp2(input * n - n);}
float3 P(float3 input, float n) {n = n * 1.4427f + 1.4427f; return exp2(input * n - n);}
float4 P(float4 input, float n) {n = n * 1.4427f + 1.4427f; return exp2(input * n - n);}

half P(half input, half n) {n = n * 1.4427f + 1.4427f; return exp2(input * n - n);}
half2 P(half2 input, half n) {n = n * 1.4427f + 1.4427f; return exp2(input * n - n);}
half3 P(half3 input, half n) {n = n * 1.4427f + 1.4427f; return exp2(input * n - n);}
half4 P(half4 input, half n) {n = n * 1.4427f + 1.4427f; return exp2(input * n - n);}

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

FLOAT_HALF_VECTOR1_INPUT1(P2, input, return input * input;)
FLOAT_HALF_VECTOR1_INPUT1(P3, input, return input * input * input;)
FLOAT_HALF_VECTOR1_INPUT1(P4, input, input = P2(input); return input * input;)
FLOAT_HALF_VECTOR1_INPUT1(Max1, input, return min(input, 1);)
FLOAT_HALF_VECTOR1_INPUT1(Min0, input, return max(input, 0);)
FLOAT_HALF_VECTOR1_INPUT1(ClampMin, input, return max(input, HALF_MIN_SQRT);)

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

float OneMinusP5(float input) {return exp2((-5.55473 * input - 6.98316) * input);}
half OneMinusP5(half input) {return exp2((-5.55473 * input - 6.98316) * input);}

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

float ClampDot(float3 dir1, float3 dir2) {return ClampMin(dot(dir1, dir2));}
half ClampDot(half3 dir1, half3 dir2) {return ClampMin(dot(dir1, dir2));}

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

float Dither4x4(float2 screenUV)
{
    float table_4x4[16] = {
        0., 8., 2., 10,
        12, 4., 14, 6.,
        3., 11, 1., 9.,
        15, 7., 13, 5.
    };
    screenUV = floor(frac(screenUV * _ScreenParams.xy * 0.25) * 4); //分为 4*4 像素一组,每组 x = 0-3, y = 0-3
    #ifdef SHADER_API_GLES
        int index = int(screenUV.y) * 4 + int(screenUV.x);
    #else
        uint index = uint(screenUV.y) * 4 + uint(screenUV.x);
    #endif
    return table_4x4[index] / 16; //根据 x,y 取矩阵中对应的数值
}

//计算 dither, 8 * 8
float Dither8x8(float2 screenUV)
{
    float4 table8x8[16] = {
        0., 48, 12, 60, 3., 51, 15, 63,
        32, 16, 44, 28, 35, 19, 47, 31,
        8., 56, 4., 52, 11, 59, 7., 55,
        40, 24, 36, 20, 43, 27, 39, 23,
        2., 50, 14, 62, 1., 49, 13, 61,
        34, 18, 46, 30, 33, 17, 45, 29,
        10, 58, 6., 54, 9., 57, 5., 53,
        42, 26, 38, 22, 41, 25, 37, 21
    };
    screenUV = floor(frac(screenUV * _ScreenParams.xy * 0.125) * 8); //分为 8*8 像素一组,每组 x = 0-7, y = 0-7
    float check = saturate(screenUV.x - 3); //判断一下 x 是否大于 3,大于就返回 1, 否则返回 0
    return table8x8[screenUV.y * 2 + check][screenUV.x - 4 * check] / 64; //计算应该哪一组 table8x8,以及取哪一位
}

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

// 灰度
float Grayscale(float3 source){return source.r * 0.2125 + source.g * 0.7154 + source.b * 0.0721;}
half Grayscale(half3 source){return source.r * 0.2125 + source.g * 0.7154 + source.b * 0.0721;}

// 计算对比度 (0 ~ 1)
float3 Contrast(float3 source, float contrast){return (source - 0.5) * contrast + 0.5;}
half3 Contrast(half3 source, half contrast){return (source - 0.5) * contrast + 0.5;}

// 计算饱和度 (0 ~ 1)
float3 Saturation(float3 source, float saturation){return lerp(Grayscale(source), source, saturation);}
half3 Saturation(half3 source, float saturation){return lerp(Grayscale(source), source, saturation);}

// 色相偏移 (-1 ~ 1)
float3 ColorShift(float3 source, float3 shift){return saturate(source + shift);}
half3 ColorShift(half3 source, half3 shift){return saturate(source + shift);}

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

half3 UnpackNormalRG(half4 packedNormal, half scale = 1)
{
    half3 normal;
    
    normal.xy = packedNormal.rg * 2 - 1;
    normal.z = max(1.0e-16, sqrt(1 - saturate(dot(normal.xy, normal.xy))));
    normal.xy *= scale;
    
    return normal;
}

#endif
