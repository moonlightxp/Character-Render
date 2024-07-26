#ifndef URP_SHADER_INCLUDE_LYX_LIBRARY_UNLIGHT
#define URP_SHADER_INCLUDE_LYX_LIBRARY_UNLIGHT

// < MatCap >
float3 MatCap(float3 normalWS)
{
    float3 normalVS = mul((float3x3)UNITY_MATRIX_V, normalWS);
    float4 matCap = _MatCapTex.Sample(sampler_Linear_Clamp, normalVS.xy * 0.5 + 0.5);

    return matCap.rgb *= _MatCapColor.rgb;
}

// < Rim >
float3 Rim(float nv, float width, float4 color)
{
    float3 rim = 1 - nv;
    rim = P(rim, 1 / width);
    rim *= color.rgb * color.a;

    return rim;
}

// < 后处理调色 >
void PostProcess(float brightness, float saturation, float contrast, inout float4 output)
{
    output.rgb *= brightness;
    output.rgb = Saturation(output.rgb, saturation);
    output.rgb = Contrast(output.rgb, contrast);
}

#endif