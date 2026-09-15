import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { useLang } from '../../context/LanguageContext';
import { jwtAPI } from '../../services/api';
import '../Login/Login.css';
import './Register.css';

export default function Register() {
    const [fullName, setFullName] = useState('');
    const [username, setUsername] = useState('');
    const [email,    setEmail]    = useState('');
    const [password, setPassword] = useState('');
    const [error,    setError]    = useState('');
    const [loading,  setLoading]  = useState(false);
    const { login } = useAuth();
    const { t }      = useLang();
    const navigate  = useNavigate();

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError('');

        if (!fullName.trim() || !email.trim() || !password) {
            setError(t('register.errorEmpty'));
            return;
        }
        if (password.length < 6) {
            setError(t('register.errorPwLength'));
            return;
        }

        setLoading(true);
        try {
            // POST /api/jwt-auth/register/ → returns access + refresh + user
            const res = await jwtAPI.register({
                full_name: fullName.trim(),
                username:  username.trim(),
                email:     email.trim(),
                password,
            });
            const { access, refresh, user } = res.data;

            localStorage.setItem('ss_token',   access);
            localStorage.setItem('ss_refresh', refresh);

            let currentUser = user;
            if (!currentUser) {
                const meRes = await jwtAPI.me();
                currentUser = meRes.data;
            }
            login(access, currentUser);

            navigate(currentUser?.role === 'ADMIN' ? '/dashboard' : '/home');
        } catch (err) {
            console.error('Register error:', err);
            const data = err.response?.data;
            const firstFieldError =
                data && typeof data === 'object'
                    ? Object.values(data).flat().find(Boolean)
                    : null;
            setError(firstFieldError || data?.detail || 'Registration failed. Please try again.');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="login-page theme-patient">

            {/* ── Branded hero panel ───────────────────────────────────────────── */}
            <div className="login-hero">
                <div className="login-hero-top">
                    <div className="login-hero-logo-icon">S</div>
                    <span className="login-hero-brand-name">DermaScanAI</span>
                </div>

                <div className="login-hero-content">
                    <h1 className="login-hero-title">{t('register.heroTitle')}</h1>
                    <p className="login-hero-sub">{t('register.heroSub')}</p>
                </div>

                <div className="login-hero-footer">DermaScanAI &copy; {new Date().getFullYear()}</div>
            </div>

            {/* ── Form panel ───────────────────────────────────────────────────── */}
            <div className="login-form-panel">
                <div className="login-card">
                    <div className="login-card-header">
                        <h2 className="login-card-title">{t('register.title')}</h2>
                        <p className="login-card-sub">{t('register.subtitle')}</p>
                    </div>
                    <form className="login-form" onSubmit={handleSubmit}>
                        <div className="login-field">
                            <label className="login-label">{t('register.fullNameLabel')}</label>
                            <input
                                className="login-input"
                                type="text"
                                placeholder="Jane Doe"
                                value={fullName}
                                onChange={e => setFullName(e.target.value)}
                                autoFocus
                            />
                        </div>
                        <div className="login-field">
                            <label className="login-label">
                                {t('register.usernameLabel')}
                                <span className="register-optional"> ({t('register.usernameOptional')})</span>
                            </label>
                            <input
                                className="login-input"
                                type="text"
                                placeholder="janedoe"
                                value={username}
                                onChange={e => setUsername(e.target.value)}
                            />
                        </div>
                        <div className="login-field">
                            <label className="login-label">{t('register.emailLabel')}</label>
                            <input
                                className="login-input"
                                type="email"
                                placeholder="you@example.com"
                                value={email}
                                onChange={e => setEmail(e.target.value)}
                            />
                        </div>
                        <div className="login-field">
                            <label className="login-label">{t('register.passwordLabel')}</label>
                            <input
                                className="login-input"
                                type="password"
                                placeholder="••••••••"
                                value={password}
                                onChange={e => setPassword(e.target.value)}
                            />
                        </div>
                        {error && <div className="login-error">{error}</div>}
                        <button className="login-btn" type="submit" disabled={loading}>
                            {loading ? t('register.signingUp') : t('register.signUpBtn')}
                        </button>
                        <div className="login-register-prompt">
                            {t('register.haveAccount')} <Link to="/login" className="login-register-link">{t('register.signInLink')}</Link>
                        </div>
                    </form>
                </div>
            </div>

        </div>
    );
}
