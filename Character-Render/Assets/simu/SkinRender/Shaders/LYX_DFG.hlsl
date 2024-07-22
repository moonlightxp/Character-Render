#ifndef URP_SHADER_INCLUDE_LYX_DFG
#define URP_SHADER_INCLUDE_LYX_DFG

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 法线分布函数 D (Normal Distribution Function)
 估算在受到表面粗糙度的影响下，取向方向与中间向量一致的微平面的数量
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/

// Trowbridge-Reitz GGX
float GGX(float roughness2, float nh2)
{
    float x = nh2 * (roughness2 - 1) + 1.00001; // 防止除 0
    return roughness2 / (PI * P2(x));
}

//-----------------------------------------------------
float GetDirectD(ObjData objData, LitData litData)
{
    return GGX(objData.roughness2, litData.nh2);
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 菲涅尔函数 F (Fresnel equation)
 描述在不同的表面角下表面反射的光线所占的比率
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/

float3 FresnelSchlick(float vh, float3 f0)
{
    return f0 + (1 - f0) * OneMinusP5(vh);
}

float3 FresnelSchlickRoughness(float nv, float roughness, float3 f0)
{
    return f0 + (max(f0, 1 - roughness) - f0) * OneMinusP5(nv);
}

//-----------------------------------------------------
// 直接光 F
float3 GetDirectF(ObjData objData, LitData litData)
{
    return FresnelSchlick(litData.vh, objData.f0);
}

// 间接光 F
float3 GetIndirectF(ObjData objData)
{
    return FresnelSchlickRoughness(objData.nv, objData.roughness, objData.f0);
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 几何函数 G (Geometry function)
 描述了微平面自成阴影的属性,当一个平面相对比较粗糙的时候,平面表面上的微平面有可能挡住其他的微平面从而减少表面所反射的光线。
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/

float SchlickGGX(float dot, float k)
{
    return dot / (dot * (1 - k) + k);
}
  
float SmithGGX(float nv, float nl, float k)
{
    float ggx1 = SchlickGGX(nl, k); // 视线方向的几何遮挡
    float ggx2 = SchlickGGX(nv, k); // 光线方向的几何阴影
	
    return ggx1 * ggx2;
}

//------------------------------------------------------------------------------------------------------------
float GetDirectG(ObjData objData,LitData litData)
{
    float k = P2(objData.roughness + 1) * 0.125;
    return SmithGGX(objData.nv, litData.nl, k);
}

#endif