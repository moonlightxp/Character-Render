#ifndef URP_SHADER_INCLUDE_LYX_MATH
#define URP_SHADER_INCLUDE_LYX_MATH

#define FLOAT_HALF_VECTOR1_INPUT1(Name, Input, Function) \
float Name(float Input) {Function} \
float2 Name(float2 Input) {Function} \
float3 Name(float3 Input) {Function} \
float4 Name(float4 Input) {Function} \
half Name(half Input) {Function} \
half2 Name(half2 Input) {Function} \
half3 Name(half3 Input) {Function} \
half4 Name(half4 Input) {Function} \

//-----------------------------------------------------------------------------------------------------------
float P(float input, float n) {n = n * 1.4427f + 1.4427f; return exp2(input * n - n);}
float2 P(float2 input, float n) {n = n * 1.4427f + 1.4427f; return exp2(input * n - n);}
float3 P(float3 input, float n) {n = n * 1.4427f + 1.4427f; return exp2(input * n - n);}
float4 P(float4 input, float n) {n = n * 1.4427f + 1.4427f; return exp2(input * n - n);}

half P(half input, half n) {n = n * 1.4427f + 1.4427f; return exp2(input * n - n);}
half2 P(half2 input, half n) {n = n * 1.4427f + 1.4427f; return exp2(input * n - n);}
half3 P(half3 input, half n) {n = n * 1.4427f + 1.4427f; return exp2(input * n - n);}
half4 P(half4 input, half n) {n = n * 1.4427f + 1.4427f; return exp2(input * n - n);}

//-----------------------------------------------------------------------------------------------------------
FLOAT_HALF_VECTOR1_INPUT1(P2, input, return input * input;)
FLOAT_HALF_VECTOR1_INPUT1(P3, input, return input * input * input;)
FLOAT_HALF_VECTOR1_INPUT1(P4, input, input = P2(input); return input * input;)
FLOAT_HALF_VECTOR1_INPUT1(Max1, input, return min(input, 1);)
FLOAT_HALF_VECTOR1_INPUT1(Min0, input, return max(input, 0);)
FLOAT_HALF_VECTOR1_INPUT1(ClampMin, input, return max(input, HALF_MIN_SQRT);)

//-----------------------------------------------------------------------------------------------------------
float OneMinusP5(float input) {return exp2((-5.55473 * input - 6.98316) * input);}
half OneMinusP5(half input) {return exp2((-5.55473 * input - 6.98316) * input);}

//-----------------------------------------------------------------------------------------------------------
float ClampDot(float3 dir1, float3 dir2) {return ClampMin(dot(dir1, dir2));}
half ClampDot(half3 dir1, half3 dir2) {return ClampMin(dot(dir1, dir2));}

#endif
