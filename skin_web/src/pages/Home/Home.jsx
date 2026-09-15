import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Camera, History as HistoryIcon, Contact, Sun, ArrowRight, ImageIcon, MessageCircle, Stethoscope } from 'lucide-react';
import { useLang } from '../../context/LanguageContext';
import { analysesAPI } from '../../services/api';
import './Home.css';

function SeverityBadge({ severity, t }) {
    const cls = { LOW: 'sev-pill--low', MEDIUM: 'sev-pill--medium', HIGH: 'sev-pill--high' };
    const labels = { LOW: t('conditions.low'), MEDIUM: t('conditions.medium'), HIGH: t('conditions.high') };
    return <span className={`sev-pill ${cls[severity] || ''}`}>{labels[severity] || severity}</span>;
}

// Full-bleed wave backdrop for the hero band - a gradient shape with a
// curved bottom edge, plus a few faint decorative dots scattered across it
// (skin spots being examined, on theme for a skin-scanning app), echoing an
// illustrated landing page without depending on any external image asset.
function HeroWaveBackground() {
    return (
        <svg
            className="home-hero-wave"
            viewBox="0 0 1440 420"
            preserveAspectRatio="none"
            role="presentation"
            aria-hidden="true"
        >
            <defs>
                <linearGradient id="heroGrad" x1="0" y1="0" x2="1" y2="1">
                    <stop offset="0%" stopColor="var(--primary)" />
                    <stop offset="100%" stopColor="var(--teal)" />
                </linearGradient>
            </defs>
            <path
                d="M0,0 L1440,0 L1440,300 C1140,390 700,420 360,360 C170,326 60,300 0,320 Z"
                fill="url(#heroGrad)"
            />
            <circle cx="120" cy="80" r="3" fill="#fff" opacity="0.5" />
            <circle cx="220" cy="150" r="4" fill="#fff" opacity="0.35" />
            <circle cx="1300" cy="70" r="4" fill="#fff" opacity="0.4" />
            <circle cx="1180" cy="180" r="3" fill="#fff" opacity="0.3" />
            {/* Small scattered dots suggesting skin spots/moles being examined */}
            <circle cx="70" cy="235" r="5" fill="#fff" opacity="0.22" />
            <circle cx="95" cy="255" r="3" fill="#fff" opacity="0.16" />
            <circle cx="55" cy="265" r="2.5" fill="#fff" opacity="0.14" />
            <circle cx="1350" cy="250" r="6" fill="none" stroke="#fff" strokeWidth="1.5" opacity="0.28" />
            <circle cx="1350" cy="250" r="2" fill="#fff" opacity="0.3" />
            <circle cx="1378" cy="270" r="3" fill="#fff" opacity="0.16" />
        </svg>
    );
}

function HeroIllustration() {
    return (
        <svg viewBox="0 0 360 300" className="home-hero-art" role="img" aria-label="">
            <circle cx="180" cy="150" r="88" fill="var(--surface)" />
            <rect x="140" y="118" width="80" height="60" rx="14" fill="none" stroke="var(--primary)" strokeWidth="6" />
            <rect x="162" y="104" width="24" height="16" rx="5" fill="var(--primary)" />
            <circle cx="180" cy="150" r="19" fill="none" stroke="var(--primary)" strokeWidth="6" />
            <circle cx="180" cy="150" r="8" fill="var(--primary)" />
            <circle cx="255" cy="90" r="10" fill="var(--med)" opacity="0.9" />
            <circle cx="270" cy="205" r="13" fill="var(--low)" opacity="0.85" />
            {/* Cluster of skin spots/moles being examined through the lens */}
            <circle cx="191" cy="142" r="3.5" fill="var(--teal)" opacity="0.8" />
            <circle cx="197" cy="150" r="2" fill="var(--teal)" opacity="0.6" />
            <circle cx="188" cy="150" r="1.5" fill="var(--teal)" opacity="0.5" />
            <circle cx="108" cy="215" r="6" fill="var(--med)" opacity="0.7" />
            <circle cx="122" cy="225" r="3.5" fill="var(--med)" opacity="0.5" />
        </svg>
    );
}

export default function Home() {
    const { t } = useLang();
    const [analyses, setAnalyses] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const load = async () => {
            try {
                const res = await analysesAPI.getMy();
                setAnalyses(res.data || []);
            } catch (err) {
                console.error('Failed to load recent scans:', err);
            } finally {
                setLoading(false);
            }
        };
        load();
    }, []);

    const latest = analyses[0];
    const latestDate = latest?.created_at ? latest.created_at.slice(0, 10) : null;

    return (
        <div className="home-page">
            <div className="home-hero-band">
                <HeroWaveBackground />
                <div className="home-hero-inner">
                    <div className="home-hero-text">
                        <h1 className="home-name">{t('home.heroTitle')}</h1>
                        <p className="home-hero-sub">{t('home.heroSub')}</p>
                        <div className="home-hero-actions">
                            <Link to="/scan" className="btn btn--hero-primary">
                                <Camera size={16} strokeWidth={1.8} />
                                {t('home.scanCta')}
                                <ArrowRight size={15} strokeWidth={1.8} />
                            </Link>
                            <Link to="/find-dermatologist" className="btn btn--hero-outline">
                                {t('home.findDermatologist')}
                            </Link>
                        </div>
                    </div>
                    <HeroIllustration />
                </div>
            </div>

            <div className="home-features-band">
                <div className="home-features-inner">
                    <p className="home-features-heading">{t('home.whyTitle')}</p>
                    <div className="home-features-grid">
                        <div className="home-feature">
                            <div className="home-feature-icon"><Camera size={22} strokeWidth={1.7} /></div>
                            <span className="home-feature-title">{t('home.feature1Title')}</span>
                            <span className="home-feature-sub">{t('home.feature1Sub')}</span>
                        </div>
                        <div className="home-feature">
                            <div className="home-feature-icon"><MessageCircle size={22} strokeWidth={1.7} /></div>
                            <span className="home-feature-title">{t('home.feature2Title')}</span>
                            <span className="home-feature-sub">{t('home.feature2Sub')}</span>
                        </div>
                        <div className="home-feature">
                            <div className="home-feature-icon"><Stethoscope size={22} strokeWidth={1.7} /></div>
                            <span className="home-feature-title">{t('home.feature3Title')}</span>
                            <span className="home-feature-sub">{t('home.feature3Sub')}</span>
                        </div>
                    </div>
                </div>
            </div>

            <div className="home-page-inner">
                <p className="home-section-heading">{t('home.activity')}</p>
                <div className="home-grid">
                    <Link to="/history" className="home-tile home-tile--history">
                        <div className="home-tile-icon"><HistoryIcon size={19} strokeWidth={1.8} /></div>
                        <span className="home-tile-title">{t('home.recentScans')}</span>
                        <span className="home-tile-sub">
                            {loading ? t('common.loading') : `${analyses.length} ${t('home.scansUnit')}`}
                        </span>
                    </Link>

                    <div className="home-tile home-tile--latest">
                        <div className="home-tile-icon"><ImageIcon size={19} strokeWidth={1.8} /></div>
                        <span className="home-tile-title">{t('home.latestResult')}</span>
                        {!loading && latest ? (
                            <Link to={`/scan/${latest.id}`} className="home-tile-latest-body">
                                <span className="home-tile-latest-name">{latest.condition_name || '—'}</span>
                                <span className="home-tile-sub">{latestDate}</span>
                                <SeverityBadge severity={latest.severity} t={t} />
                            </Link>
                        ) : (
                            <span className="home-tile-sub">{loading ? t('common.loading') : t('history.empty')}</span>
                        )}
                    </div>

                    <Link to="/find-dermatologist" className="home-tile home-tile--derm">
                        <div className="home-tile-icon"><Contact size={19} strokeWidth={1.8} /></div>
                        <span className="home-tile-title">{t('home.findDermatologist')}</span>
                        <span className="home-tile-sub">{t('home.findDermatologistSub')}</span>
                    </Link>
                </div>

                <div className="home-tip">
                    <Sun size={18} strokeWidth={1.8} />
                    <span>{t('home.tip')}</span>
                </div>
            </div>
        </div>
    );
}
