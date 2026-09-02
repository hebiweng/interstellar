export function TimeDependentUnavailable({ title, detail }: { title: string; detail: string }) {
  return <section className="time-dependent-unavailable"><span>需要出生时间</span><h3>{title}</h3><p>{detail}</p><ul><li>系统不会把 00:00 或日期中点当作出生时刻。</li><li>补充可靠的当地出生时间后，请重新计算。</li><li>当前仍可查看日期级天体位置、不确定范围及可能的跨星座／运动状态变化。</li></ul></section>;
}
