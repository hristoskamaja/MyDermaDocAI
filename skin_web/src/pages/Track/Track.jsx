import { Link } from 'react-router-dom';
import { Sprout } from 'lucide-react';
import { useLang } from '../../context/LanguageContext';

// Placeholder until the skin tracker (check-ins, routine, timeline) ships.
export default function Track() {
    const { t } = useLang();
    return (
        <div>
            <div className="pt-page-header">
                <p className="pt-eyebrow">{t('track.eyebrow')}</p>
                <h1 className="pt-title">{t('track.title')}</h1>
                <p className="pt-subtitle">{t('track.subtitle')}</p>
            </div>
            <div className="pt-card" style={{ maxWidth: 520, display: 'flex', flexDirection: 'column', gap: 12, alignItems: 'flex-start' }}>
                <span className="pt-icon-chip"><Sprout size={20} strokeWidth={1.8} /></span>
                <h2 className="pt-h2">{t('track.soonTitle')}</h2>
                <p className="pt-subtitle" style={{ marginTop: 0 }}>{t('track.soonText')}</p>
                <Link to="/scan" className="pt-btn">{t('nav.scan')}</Link>
            </div>
        </div>
    );
}
