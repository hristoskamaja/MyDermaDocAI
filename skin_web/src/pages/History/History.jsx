import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { ImageIcon, ChevronRight, Camera } from 'lucide-react';
import { useLang } from '../../context/LanguageContext';
import { analysesAPI } from '../../services/api';
import PageHeroWave from '../../components/decor/PageHeroWave';
import './History.css';

function SeverityBadge({ severity, t }) {
    const cls = { LOW: 'sev-pill--low', MEDIUM: 'sev-pill--medium', HIGH: 'sev-pill--high' };
    const labels = { LOW: t('conditions.low'), MEDIUM: t('conditions.medium'), HIGH: t('conditions.high') };
    return <span className={`sev-pill ${cls[severity] || ''}`}>{labels[severity] || severity}</span>;
}

export default function History() {
    const { t } = useLang();
    const [analyses, setAnalyses] = useState([]);
    const [loading, setLoading]   = useState(true);

    useEffect(() => {
        const load = async () => {
            try {
                const res = await analysesAPI.getMy();
                setAnalyses(res.data || []);
            } catch (err) {
                console.error('Failed to load history:', err);
            } finally {
                setLoading(false);
            }
        };
        load();
    }, []);

    if (loading) return <div className="hist-loading">{t('common.loading')}</div>;

    return (
        <div className="history-page">
            <div className="page-hero-band">
                <PageHeroWave />
                <div className="page-hero-inner">
                    <div className="page-header">
                        <div>
                            <h1 className="page-title">{t('history.title')}</h1>
                            <p className="page-subtitle">{t('history.subtitle')}</p>
                        </div>
                    </div>
                </div>
            </div>

            {analyses.length === 0 ? (
                <div className="hist-empty">
                    <div className="hist-empty-icon"><Camera size={24} strokeWidth={1.6} /></div>
                    <span className="hist-empty-title">{t('history.empty')}</span>
                    <span className="hist-empty-sub">{t('history.emptySub')}</span>
                    <Link to="/scan" className="btn btn--primary" style={{ marginTop: 10 }}>
                        <Camera size={15} strokeWidth={1.8} /> {t('history.newScanBtn')}
                    </Link>
                </div>
            ) : (
                <div className="hist-list">
                    {analyses.map(a => {
                        const dateStr = a.created_at ? a.created_at.slice(0, 10) : '—';
                        const confidencePct = a.confidence != null ? `${(a.confidence * 100).toFixed(0)}%` : '—';
                        const sevClass = { LOW: 'hist-item--low', MEDIUM: 'hist-item--medium', HIGH: 'hist-item--high' }[a.severity] || '';
                        return (
                            <Link key={a.id} to={`/scan/${a.id}`} className={`hist-item ${sevClass}`}>
                                <div className="hist-item-thumb">
                                    <ImageIcon size={16} strokeWidth={1.6} />
                                </div>
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
