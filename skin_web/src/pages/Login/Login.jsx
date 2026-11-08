import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { useLang } from '../../context/LanguageContext';
import { jwtAPI } from '../../services/api';
import AuthShell from '../../components/layout/AuthShell';

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
        <AuthShell>
            <h1>{t('login.heading')}</h1>
            <p className="pt-auth-sub">{t('login.patientSubtitle')}</p>
            <form className="pt-auth-form" onSubmit={handleSubmit}>
                <div className="pt-field">
                    <label className="pt-label" htmlFor="login-email">{t('login.emailLabel')}</label>
                    <input
                        id="login-email"
                        className="pt-input"
                        type="email"
                        placeholder="you@example.com"
                        value={email}
                        onChange={e => setEmail(e.target.value)}
                        autoFocus
                    />
                </div>
                <div className="pt-field">
                    <label className="pt-label" htmlFor="login-password">{t('login.passwordLabel')}</label>
                    <input
                        id="login-password"
                        className="pt-input"
                        type="password"
                        placeholder="••••••••"
                        value={password}
                        onChange={e => setPassword(e.target.value)}
                    />
                </div>
                {error && <div className="pt-alert pt-alert--error">{error}</div>}
                <button className="pt-btn pt-btn--block" type="submit" disabled={loading}>
                    {loading ? t('login.signingIn') : t('login.signInBtn')}
                </button>
                <div className="pt-auth-foot">
                    <Link to="/forgot-password" className="pt-link">{t('login.forgotPassword')}</Link>
                </div>
                <div className="pt-auth-foot">
                    {t('login.noAccount')} <Link to="/register" className="pt-link">{t('login.signUpLink')}</Link>
                </div>
            </form>
        </AuthShell>
    );
}
