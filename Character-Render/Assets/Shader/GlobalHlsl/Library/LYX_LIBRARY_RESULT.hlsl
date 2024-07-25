#ifndef URP_SHADER_INCLUDE_LYX_LIBRARY_RESULT
#define URP_SHADER_INCLUDE_LYX_LIBRARY_RESULT

// 计算好的光照数据
struct LitResultData
{
    float3 DirectDiffuse; // 直接光漫反射
    float3 DirectSpecular; // 直接光镜面反射

    float3 InDirectDiffuse; // 间接光漫反射
    float3 InDirectSpecular; // 间接光镜面反射
};

#endif
