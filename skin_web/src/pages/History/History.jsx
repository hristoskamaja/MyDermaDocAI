import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { ImageIcon, ChevronRight, Camera } from 'lucide-react';
import { useLang } from '../../context/LanguageContext';
import { analysesAPI } from '../../services/api';
import './History.css';

function SeverityBadge({ severity, t }) {
    const cls = { LOW: 'sev-pill--low', MEDIUM: 'sev-pill--medium', HIGH: 'sev-pill--high' };
    const labels = { LOW: t('conditions.low'), MEDIUM: t('conditions.medium'), HIGH: t('conditions.high') };
    return <span className={`sev-pill ${cls[severity] || ''}`}>{labels[severity] || severity}</span>;
}

export default function History() {
    const { t, lang } = useLang();
    const [analyses, setAnalyses] = useState([]);
    const [loading, setLoading]   = useState(true);
    const [refreshing, setRefreshing] = useState(false);

    // Refetches on language change (condition names are localized). The old
    // list stays visible, slightly dimmed, until the new one arrives.
    useEffect(() => {
        let cancelled = false;
        const load = async () => {
            setRefreshing(true);
            try {
                const res = await analysesAPI.getMy();
                if (!cancelled) setAnalyses(res.data || []);
            } catch (err) {
                console.error('Failed to load history:', err);
            } finally {
                if (!cancelled) { setLoading(false); setRefreshing(false); }
            }
        };
        load();
        return () => { cancelled = true; };
    }, [lang]);

    if (loading) return <div className="pt-loading">{t('common.loading')}</div>;

    return (
        <div className="history-page">
            <div className="pt-page-header">
                <h1 className="pt-title">{t('history.title')}</h1>
                <p className="pt-subtitle">{t('history.subtitle')}</p>
            </div>

            {analyses.length === 0 ? (
                <div className="pt-card hist-empty">
                    <span className="pt-icon-chip"><Camera size={20} strokeWidth={1.7} /></span>
                    <span className="pt-h2">{t('history.empty')}</span>
                    <span className="pt-subtitle" style={{ marginTop: 0 }}>{t('history.emptySub')}</span>
                    <Link to="/scan" className="pt-btn" style={{ marginTop: 8 }}>
                        <Camera size={15} strokeWidth={1.8} /> {t('history.newScanBtn')}
                    </Link>
                </div>
            ) : (
                <div className={`hist-list${refreshing ? ' pt-refreshing' : ''}`}>
                    {analyses.map(a => {
                        const dateStr = a.created_at ? a.created_at.slice(0, 10) : '—';
                        const confidencePct = a.confidence != null ? `${(a.confidence * 100).toFixed(0)}%` : '—';
                        return (
                            <Link key={a.id} to={`/scan/${a.id}`} className="pt-card hist-item">
                                <span className="pt-icon-chip"><ImageIcon size={17} strokeWidth={1.7} /></span>
                                <div className="hist-item-main">
                                    <div className="hist-item-top">
                                        <span className="hist-item-name">{a.condition_name || '—'}</span>
                                        <SeverityBadge severity={a.severity} t={t} />
                                    </div>
                                    <div className="hist-item-sub">
                                        {t('analyses.aiConfidence')}: {confidencePct} · {dateStr}
                                        {a.is_low_confidence && <span className="hist-item-flag"> · {t('analyses.uncertain')}</span>}
                                    </div>
                                </div>
                                <ChevronRight size={18} strokeWidth={1.8} className="hist-item-chevron" />
                            </Link>
                        );
                    })}
                </div>
            )}
        </div>
    );
}
