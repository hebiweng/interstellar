export function CalculationUnavailable({ title, detail }: { title: string; detail: string }) {
  return <section className="calculation-unavailable"><span>当前结果暂无数据</span><h3>{title}</h3><p>{detail}</p></section>;
}
