---
card_id: ALG-ASTRONOMY-004
capability_id: astronomy.aspects
status: review
phase: alpha
calculation_ids: [aspect.major.v1, aspect.minor.v1, aspect.harmonic.v1, aspect.declination.v1, aspect.latitude.v1, aspect.mirror.v1]
result_contracts: [AspectResult]
---

# 相位

两点黄经差取最小角距`d=min(|a-b|,360-|a-b|)`；相位误差为`|d-target|`，命中条件`error<=effective_orb`。有效容许度来自版本化OrbProfile，可按双方点、盘型和相位缩放；不得在算法中内置吉凶。入相/出相以相位有符号误差在短时间推进后的绝对值变小/变大判定，停滞附近用速度导数和求根结果复核。动态相位记录进入、全部精确和离开，粗扫步长必须小于最快对象穿越最窄容许度时间的一半。平行/反平行使用赤纬，镜像点按巨蟹/摩羯轴和白羊/天秤轴定义。属性测试覆盖交换对称、0/360、跨星座、逆行三次命中；精确时间容差个人行星60秒、慢行星5分钟。

## M3实现记录（2026-07-18）

- 已实现合相、六分、刑、拱、冲五个主要相位及版本化Aspect/Orb Profile；
- 当前黄经与速度可判定exact/applying/separating/indeterminate，跨0°、交换对称、稳定ID和容许度边界已通过属性测试；
- M3快照对所选点的全部无序对生成Canonical Aspect，不赋予吉凶意义；
- 动态进入、全部精确、离开、逆行多次命中、次要/谐波/赤纬/纬度/镜像相位尚未实现，继续由M5及Beta阶段完成，因此本卡为`review/in_progress/experimental`。
