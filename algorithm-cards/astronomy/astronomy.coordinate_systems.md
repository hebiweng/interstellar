---
card_id: ALG-ASTRONOMY-002
capability_id: astronomy.coordinate_systems
status: review
phase: beta
calculation_ids: [time.solar_sidereal.v1, time.earth_orientation.v1, coordinate.ecliptic.v1, coordinate.equatorial.v1, coordinate.horizontal.v1, coordinate.heliocentric.v1, coordinate.topocentric.v1, coordinate.local_space.v1, coordinate.latitude_declination.v1]
result_contracts: [AstronomicalContext, CelestialPosition]
---

# 坐标系统

黄道、赤道、地平坐标都保留`frame/center/epoch/position_kind`。黄道转赤道采用同一时刻真/平黄赤交角，禁止混合；赤经规范化`[0,360)`。地平坐标由当地视恒星时计算时角，方位角定义为北点起顺时针`[0,360)`，高度`[-90,90]`；折射前后分别保存。拓扑中心先设置经纬海拔再调用Swiss，海拔未知时明确使用0米近似并警告。日心位置不计算地球宫位。Local Space使用天体高度/方位，地下点可保留但默认虚线。测试与SOFA/ERFA或SPICE同参数差异验证，坐标往返误差`<1e-9 rad`。
