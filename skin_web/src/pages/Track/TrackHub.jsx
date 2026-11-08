import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Flame, Check, ArrowRight, Sparkles, Utensils, Moon, Brain, CalendarHeart, Droplet } from 'lucide-react';
import { useLang } from '../../context/LanguageContext';
import { trackingAPI } from '../../services/api';
import LoadState from './components/LoadState';
import { StartEmpty } from './components/EmptyState';
import { fmt, levelClass, longDate } from './trackUtils';

export default function TrackHub() {
    const { t, lang } = useLang();
    const [today, setToday] = useState(null);
    const [week, setWeek] = useState([]);
    const [insight, setInsight] = useState(null);
    const [reminders, setReminders] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');

    const load = useCallback(async () => {
        setLoading(true);
        setError('');
        try {
            const [todayRes, weekRes, remRes] = await Promise.all([
                trackingAPI.getToday(), trackingAPI.getWeek(), trackingAPI.getReminders(),
            ]);
            setToday(todayRes.data);
            setWeek(weekRes.data.days || []);
            setReminders(remRes.data);
        } catch {
            setError(t('track.error'));
        } finally {
            setLoading(false);
        }
        // The banner is a nice-to-have: a failure here must not break the hub.
        try {
            const res = await trackingAPI.getInsights();
            setInsight(res.data.enough_data ? res.data.featured : null);
        } catch {
            setInsight(null);
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [lang]);

    useEffect(() => { load(); }, [load]);

    if (loading || error) return <LoadState loading={loading} error={error} onRetry={load} />;
    if (!today.total_check_ins) return <StartEmpty />;

    const log = today.today_log;
    const logged = today.logged_today;

    const foodSummary = log?.food_tags?.length
        ? log.food_tags.slice(0, 2).map((k) => t(`track.food.${k}`)).join(', ')
        : t('track.hub.notLogged');
    const sleepSummary = log?.sleep_hours != null
        ? fmt(t('track.hub.hoursShort'), { n: log.sleep_hours })
        : t('track.hub.notLogged');
    const stressSummary = log?.stress != null
        ? fmt(t('track.hub.stressOf'), { n: log.stress })
        : t('track.hub.notLogged');
    const cycleSummary = !reminders?.cycle_tracking_enabled
        ? t('track.hub.cycleOff')
        : log?.cycle_phase ? t(`track.phases.${log.cycle_phase}`) : t('track.hub.notLogged');
    const amDone = log?.routine_am?.length || 0;
    const pmDone = log?.routine_pm?.length || 0;
    const skincareSummary = log
        ? `${t('track.hub.morningShort')} ${amDone} · ${t('track.hub.eveningShort')} ${pmDone}`
        : t('track.hub.notLogged');

    const tiles = [
        { key: 'food',     Icon: Utensils,      label: t('track.hub.food'),     value: foodSummary },
        { key: 'sleep',    Icon: Moon,          label: t('track.hub.sleep'),    value: sleepSummary },
        { key: 'stress',   Icon: Brain,         label: t('track.hub.stress'),   value: stressSummary },
        { key: 'cycle',    Icon: CalendarHeart, label: t('track.hub.cycle'),    value: cycleSummary },
        { key: 'skincare', Icon: Droplet,       label: t('track.hub.skincare'), value: skincareSummary },
    ];

    return (
        <div className="tr-stack">
            <div className="tr-hub-top">
                <div className="pt-card tr-cta">
                    <p className="tr-eyebrow-sm">{t('track.hub.today')} · {longDate(today.date, lang)}</p>
                    <h2 className="tr-cta-title">{logged ? t('track.hub.done') : t('track.hub.notYet')}</h2>
                    <p className="tr-muted">{logged ? t('track.hub.doneSub') : t('track.hub.notYetSub')}</p>
                    <Link to="/track/check-in" className="pt-btn tr-cta-btn">
                        {logged ? t('track.hub.edit') : t('track.hub.start')} <ArrowRight size={16} />
                    </Link>
                </div>

                <div className="pt-card tr-streak">
                    <span className="pt-icon-chip tr-streak-icon"><Flame size={22} strokeWidth={1.8} /></span>
                    <div className="tr-streak-num">{today.streak.current}</div>
                    <div className="tr-muted">{t('track.hub.streak')} · {t('track.hub.best')} {today.streak.best}</div>
                </div>
            </div>

            <div className="pt-card">
                <div className="tr-row-between">
                    <h2 className="pt-h2">{t('track.hub.thisWeek')}</h2>
                    <Link to="/track/timeline" className="pt-link tr-small">{t('track.hub.timelineLink')}</Link>
                </div>
                <div className="tr-week">
                    {week.map((day) => (
                        <div key={day.date} className="tr-week-day">
                            <span className="tr-week-label">{t(`track.weekdays.${day.weekday}`)}</span>
                            <span
                                className={`tr-week-dot ${levelClass(day.level)}${day.is_today ? ' tr-week-dot--today' : ''}${day.is_future ? ' tr-week-dot--future' : ''}`}
                                title={day.logged ? t(`track.severity.${day.level}`) : ''}
                            >
                                {day.logged ? <Check size={16} strokeWidth={2.4} /> : Number(day.date.slice(8, 10))}
                            </span>
                        </div>
                    ))}
                </div>
            </div>

            <div className="tr-tiles">
                {tiles.map(({ key, Icon, label, value }) => (
                    <Link key={key} to={key === 'skincare' ? '/track/routine' : '/track/check-in'} className="pt-card tr-tile">
                        <span className="pt-icon-chip"><Icon size={18} strokeWidth={1.8} /></span>
                        <span className="tr-tile-label">{label}</span>
                        <span className="tr-tile-value">{value}</span>
                    </Link>
                ))}
            </div>

            {insight && (
                <Link to="/track/insights" className="tr-banner">
                    <span className="pt-icon-chip"><Sparkles size={18} strokeWidth={1.8} /></span>
                    <span className="tr-banner-text">{insight.text}</span>
                    <ArrowRight size={18} />
                </Link>
            )}
        </div>
    );
}
