import { Link } from 'react-router-dom';
import { Sprout, Hourglass } from 'lucide-react';
import { useLang } from '../../../context/LanguageContext';
import { fmt } from '../trackUtils';

// "Start tracking your skin" - shown when there are no check-ins at all.
export function StartEmpty() {
    const { t } = useLang();
    return (
        <div className="pt-card tr-empty">
            <span className="pt-icon-chip tr-empty-icon"><Sprout size={22} strokeWidth={1.8} /></span>
            <h2 className="pt-h2">{t('track.empty.startTitle')}</h2>
            <p className="tr-muted">{t('track.empty.startText')}</p>
            <Link to="/track/check-in" className="pt-btn">{t('track.empty.firstCheckin')}</Link>
        </div>
    );
}

// "Not enough data yet" with a progress bar of logged days out of the minimum.
export function NotEnoughData({ logged = 0, needed = 7 }) {
    const { t } = useLang();
    const done = Math.min(logged, needed);
    const pct = needed ? Math.round((done / needed) * 100) : 0;
    return (
        <div className="pt-card tr-empty">
            <span className="pt-icon-chip tr-empty-icon"><Hourglass size={22} strokeWidth={1.8} /></span>
            <h2 className="pt-h2">{t('track.empty.notEnoughTitle')}</h2>
            <p className="tr-muted">{fmt(t('track.empty.notEnoughText'), { n: needed })}</p>
            <div className="tr-progress-wrap">
                <div className="tr-progress-head">
                    <span>{fmt(t('track.empty.daysOf'), { a: done, b: needed })}</span>
                    <span>{pct}%</span>
                </div>
                <div className="tr-progress-dots" role="progressbar" aria-valuemin={0} aria-valuemax={needed} aria-valuenow={done}>
                    {Array.from({ length: needed }, (_, i) => (
                        <span key={i} className={`tr-progress-dot${i < done ? ' tr-progress-dot--on' : ''}`} />
                    ))}
                </div>
            </div>
            <Link to="/track/check-in" className="pt-btn pt-btn--ghost">{t('track.hub.start')}</Link>
        </div>
    );
}
