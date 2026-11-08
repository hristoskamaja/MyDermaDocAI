import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { LogOut } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { useLang } from '../../context/LanguageContext';
import PatientFooter from './PatientFooter';
import PatientBrand from './PatientBrand';
import AuthToolbar from './AuthToolbar';
import './PatientLayout.css';

export default function PatientLayout() {
    const { user, logout } = useAuth();
    const { t } = useLang();
    const navigate = useNavigate();

    const NAV = [
        { to: '/home',               label: t('nav.home')       },
        { to: '/scan',               label: t('nav.scan')       },
        { to: '/track',              label: t('nav.track')      },
        { to: '/history',            label: t('nav.history')    },
        { to: '/find-dermatologist', label: t('nav.doctorsTab') },
        { to: '/profile',            label: t('nav.profile')    },
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
                        <PatientBrand />
                        <span className="patient-brand-name">DermaScan<span>AI</span></span>
                    </NavLink>

                    <nav className="patient-nav">
                        {NAV.map(({ to, label }) => (
                            <NavLink
                                key={to}
                                to={to}
                                className={({ isActive }) => `patient-nav-link${isActive ? ' patient-nav-link--active' : ''}`}
                            >
                                {label}
                            </NavLink>
                        ))}
                    </nav>

                    <div className="patient-topbar-right">
                        <AuthToolbar />
                        <div className="patient-avatar" title={user?.full_name || ''}>{initial}</div>
                        <button className="patient-icon-btn" onClick={handleLogout} title={t('nav.logout')} aria-label={t('nav.logout')}>
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
