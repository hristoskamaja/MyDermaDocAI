import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { ArrowRight, History as HistoryIcon, Contact, Sun, ScanLine, ImageIcon } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { useLang } from '../../context/LanguageContext';
import { analysesAPI } from '../../services/api';
import './Home.css';

function SeverityBadge({ severity, t }) {
    const cls = { LOW: 'sev-pill--low', MEDIUM: 'sev-pill--medium', HIGH: 'sev-pill--high' };
    const labels = { LOW: t('conditions.low'), MEDIUM: t('conditions.medium'), HIGH: t('conditions.high') };
    return <span className={`sev-pill ${cls[severity] || ''}`}>{labels[severity] || severity}</span>;
}

export default function Home() {
    const { t, lang } = useLang();
    const { user } = useAuth();
    const [analyses, setAnalyses] = useState([]);
    const [loading, setLoading] = useState(true);

    // Refetches when the UI language changes (condition names come back
    // localized). The previous list stays on screen while the request runs.
    useEffect(() => {
        let cancelled = false;
        const load = async () => {
            try {
                const res = await analysesAPI.getMy();
                if (!cancelled) setAnalyses(res.data || []);
            } catch (err) {
                console.error('Failed to load recent scans:', err);
            } finally {
                if (!cancelled) setLoading(false);
            }
        };
        load();
        return () => { cancelled = true; };
    }, [lang]);

    const latest = analyses[0];
    const latestDate = latest?.created_at ? latest.created_at.slice(0, 10) : null;
    const confidencePct = latest?.confidence != null ? `${Math.round(latest.confidence * 100)}%` : null;

    const hour = new Date().getHours();
    const greeting = hour < 12 ? t('home.greetingMorning') : hour < 18 ? t('home.greetingAfternoon') : t('home.greetingEvening');
    const firstName = user?.full_name?.split(' ')[0];

    return (
        <div className="home-page">
            <div className="pt-page-header">
                <p className="pt-eyebrow">
                    {new Date().toLocaleDateString(lang === 'mk' ? 'mk-MK' : 'en-GB', { weekday: 'long', day: 'numeric', month: 'long' })}
                </p>
                <h1 className="pt-title">{firstName ? `${greeting}, ${firstName}` : greeting}</h1>
            </div>

            <section className="home-scan-card">
                <div className="home-scan-text">
                    <p className="home-scan-eyebrow">{t('home.aiSkinCheck')}</p>
                    <h2 className="home-scan-title">{t('home.scanCta')}</h2>
                    <p className="home-scan-sub">{t('home.heroSub')}</p>
                    <Link to="/scan" className="home-scan-btn">
                        {t('home.startScan')} <ArrowRight size={16} strokeWidth={1.8} />
                    </Link>
                </div>
                <ScanLine className="home-scan-icon" size={72} strokeWidth={1.2} aria-hidden="true" />
            </section>

            <div className="home-row">
                <div className={`pt-card home-last${loading ? '' : ''}`}>
                    <p className="pt-eyebrow">{t('home.lastScan')}{latestDate ? ` · ${latestDate}` : ''}</p>
                    {!loading && latest ? (
                        <Link to={`/scan/${latest.id}`} className="home-last-body">
                            <span className="pt-icon-chip"><ImageIcon size={18} strokeWidth={1.7} /></span>
                            <span className="home-last-main">
                                <span className="home-last-name">{latest.condition_name || '—'}</span>
                                <span className="home-last-meta">
                                    <SeverityBadge severity={latest.severity} t={t} />
                                    {confidencePct && <span>{confidencePct} {t('result.confidence').toLowerCase()}</span>}
                                </span>
                            </span>
                            <ArrowRight size={18} strokeWidth={1.8} className="home-last-arrow" />
                        </Link>
                    ) : (
                        <p className="pt-subtitle" style={{ marginTop: 12 }}>
                            {loading ? t('common.loading') : t('history.empty')}
                        </p>
                    )}
                </div>

                <Link to="/history" className="pt-card home-quick">
                    <span className="pt-icon-chip"><HistoryIcon size={18} strokeWidth={1.8} /></span>
                    <span className="home-quick-title">{t('home.recentScans')}</span>
                    <span className="home-quick-sub">{loading ? '…' : `${analyses.length} ${t('home.scansUnit')}`}</span>
                </Link>

                <Link to="/find-dermatologist" className="pt-card home-quick">
                    <span className="pt-icon-chip"><Contact size={18} strokeWidth={1.8} /></span>
                    <span className="home-quick-title">{t('nav.doctorsTab')}</span>
                    <span className="home-quick-sub">{t('home.findDermatologistSub')}</span>
                </Link>
            </div>

            <div className="pt-note">
                <Sun size={16} strokeWidth={1.8} />
                <span>{t('home.tip')}</span>
            </div>
        </div>
    );
}
