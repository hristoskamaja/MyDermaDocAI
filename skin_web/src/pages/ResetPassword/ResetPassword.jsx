import { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { CheckCircle2 } from 'lucide-react';
import { useLang } from '../../context/LanguageContext';
import { jwtAPI } from '../../services/api';
import AuthShell from '../../components/layout/AuthShell';

// Step 2 of the password reset: the page the emailed link opens
// (/reset-password?uid=...&token=...). Sends uid + token + the new password.
export default function ResetPassword() {
    const { t } = useLang();
    const [params] = useSearchParams();
    const uid   = params.get('uid') || '';
    const token = params.get('token') || '';

    const [password, setPassword] = useState('');
    const [confirm, setConfirm]   = useState('');
    const [error, setError]       = useState('');
    const [loading, setLoading]   = useState(false);
    const [done, setDone]         = useState(false);

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError('');
        if (!password || !confirm)  { setError(t('reset.errorEmpty'));  return; }
        if (password.length < 6)    { setError(t('reset.errorLength')); return; }
        if (password !== confirm)   { setError(t('reset.errorMatch'));  return; }

        setLoading(true);
        try {
            await jwtAPI.confirmPasswordReset({ uid, token, new_password: password });
            setDone(true);
        } catch (err) {
            // A 400 means the uid/token pair is wrong, expired or already used.
            setError(err.response?.status === 400 ? t('reset.errorInvalidLink') : t('reset.errorGeneric'));
        } finally {
            setLoading(false);
        }
    };

    if (!uid || !token) {
        return (
            <AuthShell>
                <h1>{t('reset.title')}</h1>
                <div className="pt-alert pt-alert--error" style={{ margin: '16px 0' }}>{t('reset.missingLink')}</div>
                <Link to="/forgot-password" className="pt-btn pt-btn--block">{t('reset.requestNew')}</Link>
            </AuthShell>
        );
    }

    if (done) {
        return (
            <AuthShell>
                <div className="pt-icon-chip" style={{ marginBottom: 16 }}><CheckCircle2 size={20} strokeWidth={1.8} /></div>
                <h1>{t('reset.successTitle')}</h1>
                <p className="pt-auth-sub">{t('reset.successText')}</p>
                <Link to="/login" className="pt-btn pt-btn--block">{t('reset.goToLogin')}</Link>
            </AuthShell>
        );
    }

    return (
        <AuthShell>
            <h1>{t('reset.title')}</h1>
            <p className="pt-auth-sub">{t('reset.subtitle')}</p>
            <form className="pt-auth-form" onSubmit={handleSubmit}>
                <div className="pt-field">
                    <label className="pt-label" htmlFor="reset-password">{t('reset.newPassword')}</label>
                    <input
                        id="reset-password"
                        className="pt-input"
                        type="password"
                        placeholder="••••••••"
                        value={password}
                        onChange={e => setPassword(e.target.value)}
                        autoFocus
                    />
                </div>
                <div className="pt-field">
                    <label className="pt-label" htmlFor="reset-confirm">{t('reset.confirmPassword')}</label>
                    <input
                        id="reset-confirm"
                        className="pt-input"
                        type="password"
                        placeholder="••••••••"
                        value={confirm}
                        onChange={e => setConfirm(e.target.value)}
                    />
                </div>
                {error && (
                    <div className="pt-alert pt-alert--error">
                        {error}
                        {error === t('reset.errorInvalidLink') && (
                            <> <Link to="/forgot-password" className="pt-link">{t('reset.requestNew')}</Link></>
                        )}
                    </div>
                )}
                <button className="pt-btn pt-btn--block" type="submit" disabled={loading}>
                    {loading ? t('reset.submitting') : t('reset.submitBtn')}
                </button>
            </form>
        </AuthShell>
    );
}
