import { useCallback, useEffect, useMemo, useState } from 'react';
import {
    ResponsiveContainer, ComposedChart, Area, Line, XAxis, YAxis, CartesianGrid, Tooltip, ReferenceArea,
} from 'recharts';
import { useLang } from '../../context/LanguageContext';
import { trackingAPI } from '../../services/api';
import LoadState from './components/LoadState';
import { StartEmpty } from './components/EmptyState';
import useTrackingPhoto from './useTrackingPhoto';
import { daysAgoISO, shortDate, toISODate } from './trackUtils';

const SERIES_COLORS = {
    acne:   'var(--high)',
    sleep:  'var(--primary)',
    stress: 'var(--med)',
};
const PHASE_FILL = {
    menstrual:  'var(--high-bg)',
    follicular: 'var(--low-bg)',
    ovulation:  'var(--info-bg)',
    luteal:     'var(--med-bg)',
};

// Sleep (0-12 h) and stress (1-10) are rescaled onto the 0-3 acne axis so the
// three lines share one chart; the tooltip always shows the real values.
const toScale = (value, max) => (value === null || value === undefined ? null : (value / max) * 3);

function PhotoBox({ day, label }) {
    const { t, lang } = useLang();
    const { url, loading } = useTrackingPhoto(day, !!day);
    return (
        <figure className="tr-ba-item">
            <div className="tr-ba-frame">
                {url
                    ? <img src={url} alt={`${label} ${shortDate(day, lang)}`} />
                    : <span className="tr-muted">{loading ? t('common.loading') : '–'}</span>}
            </div>
            <figcaption>{label}{day ? ` · ${shortDate(day, lang)}` : ''}</figcaption>
        </figure>
    );
}

function ChartTooltip({ active, payload, label, lang, t }) {
    if (!active || !payload?.length) return null;
    const row = payload[0].payload;
    return (
        <div className="tr-tooltip">
            <strong>{shortDate(label, lang)}</strong>
            {row.acne_severity !== null && <div>{t('track.timeline.acne')}: {t(`track.severity.${['clear', 'mild', 'moderate', 'severe'][row.acne_severity]}`)}</div>}
            {row.sleep_hours !== null && <div>{t('track.timeline.sleep')}: {row.sleep_hours} h</div>}
            {row.stress !== null && <div>{t('track.timeline.stress')}: {row.stress} / 10</div>}
            {row.cycle_phase && <div>{t('track.timeline.cycle')}: {t(`track.phases.${row.cycle_phase}`)}</div>}
        </div>
    );
}

export default function Timeline() {
    const { t, lang } = useLang();
    const [range, setRange] = useState(30);
    const [data, setData] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [show, setShow] = useState({ sleep: true, stress: true, cycle: true });
    const [beforeDay, setBeforeDay] = useState('');
    const [afterDay, setAfterDay] = useState('');

    const load = useCallback(async () => {
        setLoading(true);
        setError('');
        try {
            const res = await trackingAPI.getTimeline({ from: daysAgoISO(range - 1), to: toISODate() });
            setData(res.data);
        } catch {
            setError(t('track.error'));
        } finally {
            setLoading(false);
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [range, lang]);

    useEffect(() => { load(); }, [load]);

    const rows = useMemo(() => (data?.points || []).map((p) => ({
        ...p,
        sleepScaled: toScale(p.sleep_hours, 12),
        stressScaled: toScale(p.stress, 10),
    })), [data]);

    const photoDays = useMemo(() => rows.filter((p) => p.has_photo).map((p) => p.date), [rows]);

    // Default the comparison to the oldest and newest photo in range.
    useEffect(() => {
        if (photoDays.length >= 2) {
            setBeforeDay((prev) => (photoDays.includes(prev) ? prev : photoDays[0]));
            setAfterDay((prev) => (photoDays.includes(prev) ? prev : photoDays[photoDays.length - 1]));
        } else {
            setBeforeDay('');
            setAfterDay('');
        }
    }, [photoDays]);

    if (loading && !data) return <LoadState loading />;
    if (error) return <LoadState error={error} onRetry={load} />;
    if (!rows.length) return <StartEmpty />;

    const toggleSeries = (key) => setShow((prev) => ({ ...prev, [key]: !prev[key] }));
    const phases = data.cycle_phases || [];

    return (
        <div className={`tr-stack${loading ? ' pt-refreshing' : ''}`}>
            <div className="pt-card">
                <div className="tr-row-between tr-wrap">
                    <div className="tr-legend">
                        <span className="tr-legend-item tr-legend-item--fixed">
                            <i style={{ background: SERIES_COLORS.acne }} />{t('track.timeline.acne')}
                        </span>
                        {['sleep', 'stress', 'cycle'].map((key) => (
                            <button
                                key={key}
                                type="button"
                                className={`tr-chip${show[key] ? ' tr-chip--on' : ''}`}
                                aria-pressed={show[key]}
                                onClick={() => toggleSeries(key)}
                            >
                                {key !== 'cycle' && <i className="tr-dot" style={{ background: SERIES_COLORS[key] }} />}
                                {t(`track.timeline.${key}`)}
                            </button>
                        ))}
                    </div>
                    <div className="tr-seg tr-seg--small" role="radiogroup">
                        {[30, 90].map((days) => (
                            <button
                                key={days}
                                type="button"
                                role="radio"
                                aria-checked={range === days}
                                className={`tr-seg-btn${range === days ? ' tr-seg-btn--on' : ''}`}
                                onClick={() => setRange(days)}
                            >
                                {t(`track.timeline.range${days}`)}
                            </button>
                        ))}
                    </div>
                </div>

                <div className="tr-chart">
                    <ResponsiveContainer width="100%" height={300}>
                        <ComposedChart data={rows} margin={{ top: 12, right: 12, bottom: 0, left: -20 }}>
                            <CartesianGrid stroke="var(--border)" strokeDasharray="3 4" vertical={false} />
                            <XAxis
                                dataKey="date"
                                tickFormatter={(d) => shortDate(d, lang)}
                                tick={{ fontSize: 11, fill: 'var(--text-muted)' }}
                                axisLine={false} tickLine={false} minTickGap={32}
                            />
                            <YAxis
                                domain={[0, 3]} ticks={[0, 1, 2, 3]}
                                tickFormatter={(v) => t(`track.severity.${['clear', 'mild', 'moderate', 'severe'][v]}`)}
                                tick={{ fontSize: 11, fill: 'var(--text-muted)' }}
                                axisLine={false} tickLine={false} width={72}
                            />
                            <Tooltip content={<ChartTooltip lang={lang} t={t} />} />
                            {show.cycle && phases.map((p) => (
                                <ReferenceArea
                                    key={`${p.phase}-${p.start}`}
                                    x1={p.start} x2={p.end}
                                    fill={PHASE_FILL[p.phase]} fillOpacity={0.7} strokeOpacity={0}
                                />
                            ))}
                            <Area
                                type="monotone" dataKey="acne_severity" connectNulls
                                stroke={SERIES_COLORS.acne} strokeWidth={3}
                                fill={SERIES_COLORS.acne} fillOpacity={0.08} dot={{ r: 2.5 }}
                            />
                            {show.sleep && (
                                <Line type="monotone" dataKey="sleepScaled" connectNulls dot={false}
                                    stroke={SERIES_COLORS.sleep} strokeWidth={2} strokeDasharray="5 4" />
                            )}
                            {show.stress && (
                                <Line type="monotone" dataKey="stressScaled" connectNulls dot={false}
                                    stroke={SERIES_COLORS.stress} strokeWidth={2} strokeDasharray="5 4" />
                            )}
                        </ComposedChart>
                    </ResponsiveContainer>
                </div>
                <p className="tr-hint">
                    {t('track.timeline.chartHint')}
                    {show.cycle && phases.length > 0 && ` ${t('track.timeline.shaded')}.`}
                </p>
                {show.cycle && phases.length > 0 && (
                    <div className="tr-phase-legend">
                        {[...new Set(phases.map((p) => p.phase))].map((phase) => (
                            <span key={phase} className="tr-chip-static">
                                <i className="tr-dot" style={{ background: PHASE_FILL[phase] }} />{t(`track.phases.${phase}`)}
                            </span>
                        ))}
                    </div>
                )}
            </div>

            <h2 className="pt-h2">{t('track.timeline.beforeAfter')}</h2>
            <div className="pt-card">
                {photoDays.length < 2 ? (
                    <p className="tr-muted">{t('track.timeline.needTwoPhotos')}</p>
                ) : (
                    <>
                        <div className="tr-ba-pick">
                            {[
                                { label: t('track.timeline.before'), value: beforeDay, set: setBeforeDay },
                                { label: t('track.timeline.after'), value: afterDay, set: setAfterDay },
                            ].map(({ label, value, set }) => (
                                <label key={label} className="pt-field">
                                    <span className="pt-label">{label}</span>
                                    <select className="pt-input" value={value} onChange={(e) => set(e.target.value)}>
                                        {photoDays.map((d) => <option key={d} value={d}>{shortDate(d, lang)}</option>)}
                                    </select>
                                </label>
                            ))}
                        </div>
                        <div className="tr-ba">
                            <PhotoBox day={beforeDay} label={t('track.timeline.before')} />
                            <PhotoBox day={afterDay} label={t('track.timeline.after')} />
                        </div>
                    </>
                )}
            </div>

            {data.scans?.length > 0 && (
                <>
                    <h2 className="pt-h2">{t('track.timeline.savedScans')}</h2>
                    <div className="tr-scan-list">
                        {data.scans.map((scan) => (
                            <div key={scan.id} className="pt-card tr-scan">
                                {scan.image && <img src={scan.image} alt="" className="tr-scan-img" />}
                                <div>
                                    <strong>{scan.condition_name || '–'}</strong>
                                    <div className="tr-muted tr-small">
                                        {shortDate(scan.date, lang)}
                                        {scan.body_area && ` · ${t(`track.areas.${scan.body_area}`) !== `track.areas.${scan.body_area}` ? t(`track.areas.${scan.body_area}`) : t(`track.scanAreas.${scan.body_area}`)}`}
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>
                </>
            )}
        </div>
    );
}
