import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { Home as HomeIcon, Camera, History, UserCircle, LogOut, Contact } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { useLang } from '../../context/LanguageContext';
import PatientFooter from './PatientFooter';
import './PatientLayout.css';

export default function PatientLayout() {
    const { user, logout } = useAuth();
    const { lang, setLang, t } = useLang();
    const navigate = useNavigate();

    const NAV = [
        { to: '/home',              label: t('nav.home'),              Icon: HomeIcon },
        { to: '/scan',              label: t('nav.scan'),              Icon: Camera  },
        { to: '/history',           label: t('nav.history'),           Icon: History },
        { to: '/find-dermatologist', label: t('nav.findDermatologist'), Icon: Contact },
        { to: '/profile',           label: t('nav.profile'),           Icon: UserCircle },
    ];

    const initial = user?.full_name?.[0]?.toUpperCase() || 'U';

    const handleLogout = () => {
        logout();
        navigate('/login');
    };

    return (
        <div className="patient-layout theme-patient">
            <header className="patient-topbar">
                <div className="patient-topbar-inner">
                    <NavLink to="/home" className="patient-brand">
                        <div className="patient-brand-icon">D</div>
                        <span className="patient-brand-name">DermaScanAI</span>
                    </NavLink>

                    <nav className="patient-nav">
                        {NAV.map(({ to, label, Icon }) => (
                            <NavLink
                                key={to}
                                to={to}
                                className={({ isActive }) => `patient-nav-link${isActive ? ' patient-nav-link--active' : ''}`}
                            >
                                <Icon size={16} strokeWidth={1.8} />
                                <span>{label}</span>
                            </NavLink>
                        ))}
                    </nav>

                    <div className="patient-topbar-right">
                        <div className="patient-lang-switch">
                            <button
                                className={`patient-lang-btn${lang === 'en' ? ' patient-lang-btn--active' : ''}`}
                                onClick={() => setLang('en')}
                            >EN</button>
                            <button
                                className={`patient-lang-btn${lang === 'mk' ? ' patient-lang-btn--active' : ''}`}
                                onClick={() => setLang('mk')}
                            >MK</button>
                        </div>
                        <div className="patient-avatar" title={user?.full_name || ''}>{initial}</div>
                        <button className="patient-logout-btn" onClick={handleLogout} title={t('nav.logout')}>
                            <LogOut size={17} strokeWidth={1.8} />
                        </button>
                    </div>
                </div>
            </header>

            <main className="patient-main">
                <div className="patient-main-inner">
                    <Outlet />
                </div>
            </main>

            <PatientFooter />
        </div>
    );
}
