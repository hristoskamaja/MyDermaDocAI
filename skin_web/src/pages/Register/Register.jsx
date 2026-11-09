import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { useLang } from '../../context/LanguageContext';
import { jwtAPI } from '../../services/api';
import AuthShell from '../../components/layout/AuthShell';

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
        <AuthShell>
            <h1>{t('register.title')}</h1>
            <p className="pt-auth-sub">{t('register.subtitle')}</p>
            <form className="pt-auth-form" onSubmit={handleSubmit}>
                <div className="pt-field">
                    <label className="pt-label">{t('register.fullNameLabel')}</label>
                    <input
                        className="pt-input"
                        type="text"
                        placeholder="Jane Doe"
                        value={fullName}
                        onChange={e => setFullName(e.target.value)}
                        autoFocus
                    />
                </div>
                <div className="pt-field">
                    <label className="pt-label">
                        {t('register.usernameLabel')}
                        <span className="pt-auth-optional"> ({t('register.usernameOptional')})</span>
                    </label>
                    <input
                        className="pt-input"
                        type="text"
                        placeholder="janedoe"
                        value={username}
                        onChange={e => setUsername(e.target.value)}
                    />
                </div>
                <div className="pt-field">
                    <label className="pt-label">{t('register.emailLabel')}</label>
                    <input
                        className="pt-input"
                        type="email"
                        placeholder="you@example.com"
                        value={email}
                        onChange={e => setEmail(e.target.value)}
                    />
                </div>
                <div className="pt-field">
                    <label className="pt-label">{t('register.passwordLabel')}</label>
                    <input
                        className="pt-input"
                        type="password"
                        placeholder="••••••••"
                        value={password}
                        onChange={e => setPassword(e.target.value)}
                    />
                </div>
                {error && <div className="pt-alert pt-alert--error">{error}</div>}
                <button className="pt-btn pt-btn--block" type="submit" disabled={loading}>
                    {loading ? t('register.signingUp') : t('register.signUpBtn')}
                </button>
                <div className="pt-auth-foot">
                    {t('register.haveAccount')} <Link to="/login" className="pt-link">{t('register.signInLink')}</Link>
                </div>
            </form>
        </AuthShell>
    );
}
