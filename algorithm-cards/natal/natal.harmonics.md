---
card_id: ALG-NATAL-007
capability_id: natal.harmonics
status: review
phase: beta
calculation_ids: [harmonic.chart.v1]
result_contracts: [ChartResult]
---

# 谐波盘

N次谐波位置为`normalize(N * natal_longitude)`，N为`[1,360]`整数；默认开放2/3/4/5/7/9。谐波盘相位默认只判合相，其等价本命分相由`360/N`解释并写入元数据。宫位默认不重新计算，显示本命轴的谐波位置；若用户请求谐波宫位必须作为独立Experimental变体。结果保留本命点引用和N值。属性测试验证N=1恒等、旋转周期、相同输入确定性和无浮点360值。
