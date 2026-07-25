import { useState, useEffect, useMemo } from 'react';
import type { LocationSearchItem, NatalPersonInput } from '../../lib/interstellar-api';
import { searchLocations, InterstellarApiError } from '../../lib/interstellar-api';
import { fallbackTimezoneOptions, fallbackPlaceOptions } from '../lib/chart-constants';

export function PersonFields({ person, onChange }: { person: NatalPersonInput; onChange: (person: NatalPersonInput) => void }) {
  const [locationCandidates, setLocationCandidates] = useState<LocationSearchItem[]>([]);
  const [locationLoading, setLocationLoading] = useState(false);
  const [locationMessage, setLocationMessage] = useState("");
  const [locationSearchActive, setLocationSearchActive] = useState(false);
  const timezoneOptions = useMemo(() => {
    const supportedValuesOf = (Intl as unknown as { supportedValuesOf?: (key: string) => string[] }).supportedValuesOf;
    const supported = supportedValuesOf ? supportedValuesOf("timeZone") : fallbackTimezoneOptions;
    return [...new Set([person.timezoneId, ...supported, ...fallbackTimezoneOptions].filter(Boolean))].sort();
  }, [person.timezoneId]);

  useEffect(() => {
    const query = person.placeName.trim();
    if (!locationSearchActive || query.length < 2 || person.locationSourceId) return;
    let active = true;
    const timer = window.setTimeout(() => {
      setLocationLoading(true);
      searchLocations(query)
        .then((items) => {
          if (!active) return;
          setLocationCandidates(items);
          setLocationMessage(items.length ? "请选择与出生地相符的正式地点候选。" : "官方地点索引中没有匹配项，可继续细化地名或手动覆盖坐标。 ");
        })
        .catch((error) => {
          if (!active) return;
          const fallback = fallbackPlaceOptions
            .filter((place) => place.name.includes(query) || query.includes(place.name))
            .map<LocationSearchItem>((place, index) => ({
              id: `demo-fallback:${index}`,
              label: `${place.name} · ${place.countryCode} · 演示后备`,
              match_score: 0,
              match_reasons: ["demo_fallback"],
              location: { name: place.name, country_code: place.countryCode, admin_path: [], latitude: place.latitude, longitude: place.longitude, elevation_m: null, timezone_id: place.timezoneId, warnings: [] },
              timezone_status: "resolved",
              timezone_candidates: [{ timezone_id: place.timezoneId, confidence: "demo_fallback", boundary_match: false }],
            }));
          setLocationCandidates(fallback);
          setLocationMessage(error instanceof InterstellarApiError && error.code === "API_NOT_CONFIGURED"
            ? "当前未连接地点服务，仅显示明确标注的演示后备候选；正式计算应使用官方 GeoNames 数据集。"
            : "地点服务暂不可用。你仍可手动输入地点、时区和经纬度。 ");
        })
        .finally(() => { if (active) setLocationLoading(false); });
    }, 320);
    return () => { active = false; window.clearTimeout(timer); };
  }, [locationSearchActive, person.locationSourceId, person.placeName]);

  const selectLocation = (candidate: LocationSearchItem) => {
    const timezone = candidate.location.timezone_id ?? candidate.timezone_candidates[0]?.timezone_id ?? person.timezoneId;
    onChange({
      ...person,
      placeName: candidate.location.name,
      countryCode: candidate.location.country_code,
      latitude: candidate.location.latitude,
      longitude: candidate.location.longitude,
      timezoneId: timezone,
      locationSourceId: candidate.id,
      timezoneStatus: candidate.timezone_status,
    });
    setLocationCandidates([]);
    setLocationSearchActive(false);
    setLocationMessage(candidate.timezone_status === "resolved"
      ? `已使用 ${candidate.label}，IANA 时区由边界数据自动确认。`
      : "地点已选择，但时区处于边界歧义或弱提示状态，请在下方人工确认 IANA 时区。 ");
  };

  const updatePlaceQuery = (value: string) => {
    setLocationCandidates([]);
    setLocationSearchActive(value.trim().length >= 2);
    onChange({ ...person, placeName: value, locationSourceId: undefined, timezoneStatus: "unresolved" });
  };
  return <div className="form-grid">
    <label>名称<input value={person.displayName} onChange={(event) => onChange({ ...person, displayName: event.target.value })} placeholder="本人或关系人物名称" /></label>
    <label>与我的关系<select value={person.relation} onChange={(event) => onChange({ ...person, relation: event.target.value as NatalPersonInput["relation"] })}><option value="self">本人</option><option value="family">亲人</option><option value="partner">伴侣</option><option value="friend">朋友</option><option value="client">客户</option><option value="other">其他</option></select></label>
    <label>时间精度<select value={person.timePrecision} onChange={(event) => { const precision = event.target.value as NatalPersonInput["timePrecision"]; onChange({ ...person, timePrecision: precision, timeConfidence: precision === "date" || precision === "unknown" ? "unknown" : person.timeConfidence === "unknown" ? "low" : person.timeConfidence }); }}><option value="minute">精确到分钟</option><option value="hour">精确到小时</option><option value="date">只有日期</option><option value="unknown">出生时刻未知</option></select><small>“只有日期／时刻未知”按完整当地民用日计算范围，绝不默认 00:00。</small></label>
    <label>出生日期<input type="date" value={person.localDate} onChange={(event) => onChange({ ...person, localDate: event.target.value })} /></label>
    <label>出生时间<input type="time" value={person.localTime} disabled={person.timePrecision === "date" || person.timePrecision === "unknown"} step={person.timePrecision === "hour" ? 3600 : 60} onChange={(event) => onChange({ ...person, localTime: event.target.value })} /><small>{person.timePrecision === "date" || person.timePrecision === "unknown" ? "将只返回日期级天体位置及不确定范围；上升、宫位、相位、阿拉伯点、昼夜体系与古典时刻判断不会生成。" : "输入的是出生地当地钟表时间；系统会使用历史 IANA 时区规则换算 UTC。"}</small></label>
    <label className="location-search-field">出生城市／地区<input role="combobox" aria-autocomplete="list" aria-controls="birth-location-options" value={person.placeName} onChange={(event) => updatePlaceQuery(event.target.value)} onKeyDown={(event) => { if (event.key === "Escape") { setLocationSearchActive(false); setLocationCandidates([]); } }} placeholder="输入城市、区县或多语言地名" autoComplete="off" aria-expanded={locationSearchActive && locationCandidates.length > 0} />{locationLoading && locationSearchActive && <small>正在搜索地点…</small>}{locationSearchActive && locationCandidates.length > 0 && <span id="birth-location-options" className="location-candidates" role="listbox">{locationCandidates.map((candidate) => <button type="button" role="option" aria-selected="false" key={candidate.id} onClick={() => selectLocation(candidate)}><b>{candidate.label}</b><small>{candidate.location.latitude.toFixed(4)}, {candidate.location.longitude.toFixed(4)} · {candidate.timezone_status === "resolved" ? candidate.location.timezone_id : `时区需确认（${candidate.timezone_candidates.map((item) => item.timezone_id).join(" / ") || "无候选"}）`}</small></button>)}</span>}<small>{locationMessage || "输入至少两个字符后显示地点候选；选择后自动填写经纬度、国家和 IANA 时区。地点精确到城市或区县即可，无需填写街道或医院。"}</small></label>
    <label>IANA 时区<select value={person.timezoneId} onChange={(event) => onChange({ ...person, timezoneId: event.target.value, timezoneStatus: "manual" })}>{timezoneOptions.map((timezone) => <option key={timezone} value={timezone}>{timezone}</option>)}</select><small>{person.timezoneStatus === "ambiguous" || person.timezoneStatus === "degraded" ? "地点数据未能唯一确认时区，必须人工确认。" : "时区使用 IANA 标识；历史夏令时由规则库计算，不让用户填写 UTC 偏移。"}</small></label>
    <label>时间可信度<select value={person.timeConfidence} disabled={person.timePrecision === "date" || person.timePrecision === "unknown"} onChange={(event) => onChange({ ...person, timeConfidence: event.target.value as NatalPersonInput["timeConfidence"] })}><option value="high">高：出生证明或正式记录</option><option value="medium">中：本人或亲友记忆</option><option value="low">低：大致时间</option><option value="unknown">未知：没有出生时刻</option></select></label>
    {(person.timePrecision === "date" || person.timePrecision === "unknown") && <p className="time-precision-warning"><b>日期级模式</b><span>可以计算天体在该日期内的星座位置范围、运动方向范围与跨界风险；不能生成完整本命盘。补充可靠出生时刻后才会开放四轴、十二宫、相位和古典结果。</span></p>}
    <details className="advanced-location"><summary>高级位置覆盖</summary><div><label>纬度<input type="number" step="0.0001" value={person.latitude} onChange={(event) => onChange({ ...person, latitude: Number(event.target.value) })} /></label><label>经度<input type="number" step="0.0001" value={person.longitude} onChange={(event) => onChange({ ...person, longitude: Number(event.target.value) })} /></label></div><p>一般无需修改。国家代码由地点候选派生，仅用于消歧，不参与占星判断。</p></details>
  </div>;
}
