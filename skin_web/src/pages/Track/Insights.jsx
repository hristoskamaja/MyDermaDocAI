import { useCallback, useEffect, useState } from 'react';
import { ResponsiveContainer, ScatterChart, Scatter, XAxis, YAxis, CartesianGrid, Tooltip } from 'recharts';
import { Info, Send } from 'lucide-react';
import { useLang } from '../../context/LanguageContext';
import { trackingAPI } from '../../services/api';
import LoadState from './components/LoadState';
import { StartEmpty, NotEnoughData } from './components/EmptyState';
import { METRICS, apiErrorText, fmt } from './trackUtils';

const AXIS_DOMAIN = { sleep: [0, 12], stress: [1, 10], acne: [0, 3] };

// Confidence is a heuristic score (sample size + effect size), never a probability.
function ConfidenceBar({ value, t }) {
    return (
        <div className="tr-conf" title={t('track.insights.confidenceTip')}>
            <div className="tr-conf-head">
                <span>{t('track.insights.confidence')}</span>
                <strong>{value}%</strong>
            </div>
            <div className="tr-conf-bar"><div className="tr-conf-fill" style={{ width: `${value}%` }} /></div>
        </div>
    );
}

function InsightCard({ finding, t, featured }) {
    return (
        <article className={`pt-card tr-insight${featured ? ' tr-insight--featured' : ''}`}>
            <div className="tr-insight-tags">
                <span className="tr-tag">{finding.category_label}</span>
                <span className={`tr-tag tr-tag--${finding.strength}`}>{finding.strength_label}</span>
            </div>
            <p className="tr-insight-text">{finding.text}</p>
            <ConfidenceBar value={finding.confidence} t={t} />
        </article>
    );
}

function CorrelationExplorer() {
    const { t, lang } = useLang();
    const [x, setX] = useState('sleep');
    const [y, setY] = useState('acne');
    const [result, setResult] = useState(null);
    const [error, setError] = useState('');

    useEffect(() => {
        if (x === y) { setResult(null); return undefined; }
        let cancelled = false;
        setError('');
        trackingAPI.getCorrelation({ x, y })
            .then((res) => { if (!cancelled) setResult(res.data); })
            .catch(() => { if (!cancelled) setError(t('track.error')); });
        return () => { cancelled = true; };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [x, y, lang]);

    const select = (value, set) => (
        <select className="pt-input" value={value} onChange={(e) => set(e.target.value)}>
            {METRICS.map((m) => <option key={m} value={m}>{t(`track.insights.metrics.${m}`)}</option>)}
        </select>
    );

    return (
        <section className="pt-card tr-step">
            <h2 className="pt-h2">{t('track.insights.correlation')}</h2>
            <p className="tr-muted">{t('track.insights.correlationSub')}</p>
            <div className="tr-ba-pick">
                <label className="pt-field"><span className="pt-label">{t('track.insights.xAxis')}</span>{select(x, setX)}</label>
                <label className="pt-field"><span className="pt-label">{t('track.insights.yAxis')}</span>{select(y, setY)}</label>
            </div>

            {x === y && <div className="pt-alert pt-alert--warn">{t('track.insights.sameMetric')}</div>}
            {error && <div className="pt-alert pt-alert--error">{error}</div>}

            {result && x !== y && (
                <>
                    <div className="tr-chart">
                        <ResponsiveContainer width="100%" height={260}>
                            <ScatterChart margin={{ top: 8, right: 12, bottom: 4, left: -16 }}>
                                <CartesianGrid stroke="var(--border)" strokeDasharray="3 4" />
                                <XAxis
                                    type="number" dataKey="x" domain={AXIS_DOMAIN[x]}
                                    name={t(`track.insights.metrics.${x}`)}
                                    tick={{ fontSize: 11, fill: 'var(--text-muted)' }} axisLine={false} tickLine={false}
                                />
                                <YAxis
                                    type="number" dataKey="y" domain={AXIS_DOMAIN[y]}
                                    name={t(`track.insights.metrics.${y}`)}
                                    tick={{ fontSize: 11, fill: 'var(--text-muted)' }} axisLine={false} tickLine={false}
                                />
                                <Tooltip cursor={{ strokeDasharray: '3 3' }} />
                                <Scatter data={result.points} fill="var(--primary)" fillOpacity={0.6} />
                            </ScatterChart>
                        </ResponsiveContainer>
                    </div>
                    <p className="tr-hint">
                        {fmt(t('track.insights.pairs'), { n: result.n })} ·{' '}
                        {t('track.insights.relation')}: {result.r === null ? t('track.insights.relationNone') : result.r}
                    </p>
                </>
            )}
        </section>
    );
}

function AskPanel() {
    const { t, lang } = useLang();
    const [chips, setChips] = useState([]);
    const [question, setQuestion] = useState('');
    const [busy, setBusy] = useState(false);
    const [answer, setAnswer] = useState(null);
    const [error, setError] = useState('');

    useEffect(() => {
        let cancelled = false;
        trackingAPI.getSuggestions()
            .then((res) => { if (!cancelled) setChips(res.data); })
            .catch(() => { if (!cancelled) setChips([]); });
        return () => { cancelled = true; };
    }, [lang]);

    const ask = async (text, chip) => {
        const q = text.trim();
        if (!q || busy) return;
        setBusy(true);
        setError('');
        setAnswer(null);
        setQuestion(q);
        try {
            const res = await trackingAPI.ask({ question: q, chip });
            setAnswer(res.data);
        } catch (err) {
            setError(apiErrorText(err, t('track.insights.askError')));
        } finally {
            setBusy(false);
        }
    };

    return (
        <section className="pt-card tr-step">
            <h2 className="pt-h2">{t('track.insights.askTitle')}</h2>
            <p className="tr-muted">{t('track.insights.askSub')}</p>

            <div className="tr-chips">
                {chips.map((c) => (
                    <button key={c.chip} type="button" className="tr-chip" disabled={busy} onClick={() => ask(c.text, c.chip)}>
                        {c.text}
                    </button>
                ))}
            </div>

            <form className="tr-ask-row" onSubmit={(e) => { e.preventDefault(); ask(question); }}>
                <input
                    className="pt-input"
                    value={question}
                    maxLength={300}
                    placeholder={t('track.insights.askPlaceholder')}
                    onChange={(e) => setQuestion(e.target.value)}
                />
                <button type="submit" className="pt-btn" disabled={busy || !question.trim()}>
                    <Send size={15} /> {busy ? t('track.insights.thinking') : t('track.insights.ask')}
                </button>
            </form>

            {error && <div className="pt-alert pt-alert--error">{error}</div>}
            {answer && (
                <div className="tr-answer">
                    <p>{answer.answer}</p>
                    <p className="tr-hint">
                        {answer.source === 'ai' ? t('track.insights.answerAi') : t('track.insights.answerTemplate')}
                        {answer.disclaimer ? ` · ${answer.disclaimer}` : ''}
                    </p>
                </div>
            )}
        </section>
    );
}

export default function Insights() {
    const { t, lang } = useLang();
    const [data, setData] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');

    const load = useCallback(async () => {
        setLoading(true);
        setError('');
        try {
            const res = await trackingAPI.getInsights();
            setData(res.data);
        } catch {
            setError(t('track.error'));
        } finally {
            setLoading(false);
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [lang]);

    useEffect(() => { load(); }, [load]);

    if (loading || error) return <LoadState loading={loading} error={error} onRetry={load} />;

    // Not enough logged days: the backend answers enough_data: false.
    if (!data.enough_data) {
        return data.logged_days === 0
            ? <StartEmpty />
            : <NotEnoughData logged={data.logged_days} needed={data.min_days} />;
    }

    const others = data.findings.filter((f) => f.id !== data.featured?.id);

    return (
        <div className="tr-stack">
            <div className="pt-note">
                <Info size={18} strokeWidth={1.8} />
                <span>{data.disclaimer}</span>
            </div>

            {data.featured ? (
                <>
                    <h2 className="pt-h2">{t('track.insights.featured')}</h2>
                    <InsightCard finding={data.featured} t={t} featured />
                    {others.length > 0 && (
                        <div className="tr-insight-grid">
                            {others.map((f) => <InsightCard key={f.id} finding={f} t={t} />)}
                        </div>
                    )}
                </>
            ) : (
                <div className="pt-card"><p className="tr-muted">{t('track.insights.none')}</p></div>
            )}

            <CorrelationExplorer />
            <AskPanel />
        </div>
    );
}
