import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { useLang } from '../../context/LanguageContext';
import { jwtAPI } from '../../services/api';
import './Login.css';

export default function Login() {
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
        if (!email || !password) { setError(t('login.errorEmpty')); return; }
        setLoading(true);
        try {
            // POST /api/jwt-auth/login/ → returns access + refresh
            const res = await jwtAPI.login({ email, password });
            const { access, refresh } = res.data;

            // Store tokens
            localStorage.setItem('ss_token',   access);
            localStorage.setItem('ss_refresh', refresh);

            // Fetch the logged-in user's data
            // The token must be set before we call me()
            const meRes = await jwtAPI.me();
            login(access, meRes.data);

            navigate(meRes.data.role === 'ADMIN' ? '/dashboard' : '/home');
        } catch (err) {
            console.error('Login error:', err);
            setError(
                err.response?.data?.detail ||
                err.response?.data?.non_field_errors?.[0] ||
                'Invalid email or password.'
            );
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
                    <h1 className="login-hero-title">{t('login.headline')}</h1>
                    <p className="login-hero-sub">{t('login.headlineSub')}</p>
                </div>

                <div className="login-hero-footer">DermaScanAI &copy; {new Date().getFullYear()}</div>
            </div>

            {/* ── Form panel ───────────────────────────────────────────────────── */}
            <div className="login-form-panel">
                <div className="login-card">
                    <div className="login-card-header">
                        <h2 className="login-card-title">Sign in</h2>
                        <p className="login-card-sub">{t('login.subtitle')}</p>
                    </div>
                    <form className="login-form" onSubmit={handleSubmit}>
                        <div className="login-field">
                            <label className="login-label">{t('login.emailLabel')}</label>
                            <input
                                className="login-input"
                                type="email"
                                placeholder="admin@dermascanai.ai"
                                value={email}
                                onChange={e => setEmail(e.target.value)}
                                autoFocus
                            />
                        </div>
                        <div className="login-field">
                            <label className="login-label">{t('login.passwordLabel')}</label>
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
                            {loading ? t('login.signingIn') : t('login.signInBtn')}
                        </button>
                        <button type="button" className="login-forgot">{t('login.forgotPassword')}</button>
                        <div className="login-register-prompt">
                            {t('login.noAccount')} <Link to="/register" className="login-register-link">{t('login.signUpLink')}</Link>
                        </div>
                    </form>
                </div>
            </div>

        </div>
    );
}
