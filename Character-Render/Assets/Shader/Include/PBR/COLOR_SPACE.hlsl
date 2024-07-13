#ifndef URP_SHADER_INCLUDE_COLOR_SPACE
#define URP_SHADER_INCLUDE_COLOR_SPACE

//----------GAMMA----------LINEAR----------色彩空间转换函数----------
inline half3 GammaToLinearSpace(half3 sRGB)
{
    return sRGB * (sRGB * (sRGB * 0.305306011h + 0.682171111h) + 0.012522878h);
}

inline half GammaToLinearSpace(half value)
{
    return value * (value * (value * 0.305306011h + 0.682171111h) + 0.012522878h);
}

inline half3 LinearToGammaSpace(half3 linRGB)
{
    linRGB = max(linRGB, half3(0.h, 0.h, 0.h));
    return max(1.055h * pow(linRGB, 0.416666667h) - 0.055h, 0.h);
}

inline half LinearToGammaSpace(half value)
{
    return max(1.055h * pow(value, 0.416666667h) - 0.055h, 0.h);
}

#endif