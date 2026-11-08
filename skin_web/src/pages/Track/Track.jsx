import { NavLink, Outlet } from 'react-router-dom';
import { useLang } from '../../context/LanguageContext';
import './Track.css';

const TABS = [
    { to: '/track',           key: 'hub',       end: true },
    { to: '/track/check-in',  key: 'checkin' },
    { to: '/track/timeline',  key: 'timeline' },
    { to: '/track/insights',  key: 'insights' },
    { to: '/track/routine',   key: 'routine' },
    { to: '/track/weekly',    key: 'weekly' },
    { to: '/track/reminders', key: 'reminders' },
];

// Shell for the tracker: header, pill sub-tabs, and the active sub-page.
export default function Track() {
    const { t } = useLang();
    return (
        <div className="tr-page">
            <div className="pt-page-header">
                <p className="pt-eyebrow">{t('track.eyebrow')}</p>
                <h1 className="pt-title">{t('track.title')}</h1>
                <p className="pt-subtitle">{t('track.subtitle')}</p>
            </div>

            <nav className="tr-tabs" aria-label={t('track.eyebrow')}>
                {TABS.map(({ to, key, end }) => (
                    <NavLink
                        key={to}
                        to={to}
                        end={end}
                        className={({ isActive }) => `tr-tab${isActive ? ' tr-tab--active' : ''}`}
                    >
                        {t(`track.tabs.${key}`)}
                    </NavLink>
                ))}
            </nav>

            <Outlet />
        </div>
    );
}
