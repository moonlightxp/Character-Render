#ifndef URP_SHADER_INCLUDE_PBR_BASE_PROPERTIES
#define URP_SHADER_INCLUDE_PBR_BASE_PROPERTIES

struct Attributes
{
    float2 uv : TEXCOORD0;
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
};

struct Varings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float4 tangentWS : TEXCOORD2;
    float3 bitangentWS : TEXCOORD3;
    float3 positionWS : TEXCOORD4;
};

// CBUFFER_START(UnityPerMaterial)
//贴图
TEXTURE2D(_MainTex);
TEXTURE2D(_BumpMap);
TEXTURE2D(_GMAMap);
TEXTURE2D(_SLDMap);
TEXTURE2D(_EmissionMap);
TEXTURE2D(_MatCapTex);

SAMPLER(sampler_LinearClamp);
SAMPLER(sampler_MainTex);

#ifdef _SSS_ON
    TEXTURE2D(_SSSMap);
#endif

#ifdef _LASER_ON
    TEXTURE2D(_LaserMap);
#endif

#if defined(_ANISOTROPIC_ON) || defined(_UVANISOTROPIC_ON)
    TEXTURE2D(_HairDataMap);
#endif

#ifdef _ANISOTROPIC_ON
    TEXTURE2D(_TangentNormalMap);
#endif

//参数
#ifdef _SSS_ON
    half _SubSurface;
    float4 _SSSMap_ST;
#endif

#ifdef _LASER_ON
    float _LaserIntensity;
    float4 _LaserMap_ST;
#endif

#ifdef _DENIER_ON
    float _RimPower;
    float _Denier;
    float4 _SkinColor;
    float4 _StockingColor;
#endif

#if defined (_ANISOTROPIC_ON) || defined (_UVANISOTROPIC_ON)
    float4 _PrimarySpecularColor;
    float4 _SecondarySpecularColor;
    half _PrimarySpecularExponent;
    half _PrimarySpecularShift;
    half _SecondarySpecularExponent;
    half _SecondarySpecularShift;
#endif

half4 _Color;
half _BumpScale;
half _Cutoff;
half4 _EmissionColor;
half4 _AmbientColor;
half _AOStrength;
half _BrightnessInOcclusion;
half _Smoothness;
half _Metallic;

half _CustomLightDir2Softness;
half _BrightnessInShadow;
half4 _CustomLightDir2Color;
half4 _MatCapColor;
half4 _CustomLightDir2;

half _Brightness;
half _Saturation;
half _Hardness;

half4 _CustomLightDir1;
half4 _LightColor0;

float3 _LightDirection;
float4 _ShadowBias;
// CBUFFER_END

#endif

