---
card_id: ALG-REPORT-003
capability_id: reporting.contextual_item_interpretation
status: review
phase: alpha
calculation_ids: []
result_contracts: [ContextualInterpretation, InterpretationLayer, InterpretationProvenance]
---

# 配置与计算项的就地确定性解读

## 名称与流派

本卡定义专业工作台中的逐项上下文解读，不定义新的星历或占星计算。现代基础层采用“行星功能＋星座表达＋宫位领域＋运动/相位上下文”的显式组合；古典层读取昼夜、本质/偶然尊贵、宫主、接纳、太阳关系和可见性等已计算事实。不同流派分别输出，不静默融合。

## 参考规范

- `docs/professional-workspace-contract.yaml#contextual_item_interpretation`
- `docs/v1-development-spec.md#4121-配置解读与逐项上下文解读`
- `docs/calculation-result-catalog.md`
- 已批准的现代、古典和具体技法规则包及其来源台账

商业应用的专有报告文字、未公开权重和逆向规则不是本能力的参考实现。每条解释规则必须登记公开文献、合法授权来源或项目自主定义及其版本。

## 输入

- 不可变`CalculationSnapshot`与唯一`result_path`；
- `item_kind`：落点、宫头、本命/跨盘相位、行运命中、进入、停滞、返照命中、尊贵、接纳、Lot、中点、格局或时间区间；
- 分析体系、Rule Pack、模板语言和显示层；
- 已有的相关事实引用，包括时间质量和流派参数。

本能力不得调用星历适配器，也不得为了生成解释补算未进入Recipe的点、相位或技法。

## 输出

`ContextualInterpretation`至少包含：

- `item_ref`、`item_kind`与事实字段；
- `fact`、`basic_modern`、`classical`、`related_context`、`provenance`五层的发布状态和内容；
- Rule Pack、模板、来源、版本、内容哈希、语言、成熟度和警告；
- 相关视图、相位、命中序列和反证引用；
- `published | unavailable | not_applicable | blocked_by_input_quality`状态。

## 组合与优先级

1. 事实层逐字段读取Snapshot，不进行自然语言推断。
2. 基础现代层只在行星、星座、宫位和上下文所需输入均满足规则时命中。
3. 古典层只读取当前古典Preset声明的表、昼夜和规则，不借用其他流派默认值。
4. 运动状态只对定义允许的对象生效。太阳、月亮、轴点、Lots和计算型虚点按领域定义返回`not_applicable`，不得生成“顺行含义”。
5. 多条原子模板不直接串联；超过一个配置的综合必须交给Finding/Conflict/Priority规则。
6. 完整报告可以引用同一Evidence，但逐项解读不创建ReportDocument。

## 边界与异常

- 出生时间未知时，落宫和角点相关层返回`blocked_by_input_quality`，稳定的星座层可独立显示；
- 相位缺少入相/出相或精确时间时，只解释现有事实并标注缺失字段；
- 规则或本地化模板缺失时继续显示事实，解释层为`unavailable`，禁止通用兜底文案；
- 同一结果在不同Rule Pack下产生不同解读ID和内容哈希，不能覆盖旧版本；
- 不输出事件必然发生、成功概率、寿命或灾难断言。

## 权威测试样本与差异测试

- 主要天体十二星座与十二宫的边界样本；
- 太阳/月亮运动状态`not_applicable`样本；
- 水星逆行、停滞和顺行样本；
- 本命相位与行运相位的入相、精确、出相和逆行多次命中样本；
- 未知出生时间、DST候选和高纬宫位降级样本；
- 现代与古典规则并列、来源和版本隔离样本；
- 缺模板、缺规则、规则升级后旧解读复现样本。

差异测试比较两条独立规则执行路径的命中键、参数、层状态和引用集合；自然语言标点差异不计入算法差异，statement key、参数或来源差异必须审查。

## 允许误差

本能力不新增数值计算。所有度数、容许度和时间直接继承Snapshot允许误差；事实引用必须逐值一致。规则命中、层状态、statement key、参数、来源和版本要求完全一致。

## 成熟度

- Alpha：主要天体落座/落宫、本命主要相位和行运主要相位的中文基础层；
- Beta：古典状态、次要相位、返照、推运、Lots、中点和双语层；
- V1：所有已发布专业结果类型具备明确的解释发布状态和覆盖报告。未发布层不阻断事实计算和展示。
