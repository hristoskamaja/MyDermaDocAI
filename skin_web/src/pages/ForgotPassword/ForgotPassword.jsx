import { useState } from 'react';
import { Link } from 'react-router-dom';
import { MailCheck } from 'lucide-react';
import { useLang } from '../../context/LanguageContext';
import { jwtAPI } from '../../services/api';
import AuthShell from '../../components/layout/AuthShell';

// Step 1 of the password reset: asks the backend to email a signed link.
// The backend always answers 200 (it never reveals whether the email exists),
// so we always show the same "check your inbox" message after a valid submit.
export default function ForgotPassword() {
    const { t } = useLang();
    const [email, setEmail]     = useState('');
    const [error, setError]     = useState('');
    const [loading, setLoading] = useState(false);
    const [sent, setSent]       = useState(false);

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError('');
        if (!email.trim()) { setError(t('forgot.errorEmpty')); return; }
        setLoading(true);
        try {
            await jwtAPI.requestPasswordReset({ email: email.trim() });
            setSent(true);
        } catch (err) {
            setError(err.response?.data?.email?.[0] || t('forgot.errorGeneric'));
        } finally {
            setLoading(false);
        }
    };

    if (sent) {
        return (
            <AuthShell>
                <div className="pt-icon-chip" style={{ marginBottom: 16 }}><MailCheck size={20} strokeWidth={1.8} /></div>
                <h1>{t('forgot.sentTitle')}</h1>
                <p className="pt-auth-sub">{t('forgot.sentText')}</p>
                <Link to="/login" className="pt-btn pt-btn--ghost pt-btn--block">{t('forgot.backToLogin')}</Link>
            </AuthShell>
        );
    }

    return (
        <AuthShell>
            <h1>{t('forgot.title')}</h1>
            <p className="pt-auth-sub">{t('forgot.subtitle')}</p>
            <form className="pt-auth-form" onSubmit={handleSubmit}>
                <div className="pt-field">
                    <label className="pt-label" htmlFor="forgot-email">{t('forgot.emailLabel')}</label>
                    <input
                        id="forgot-email"
                        className="pt-input"
                        type="email"
                        placeholder="you@example.com"
                        value={email}
                        onChange={e => setEmail(e.target.value)}
                        autoFocus
                    />
                </div>
                {error && <div className="pt-alert pt-alert--error">{error}</div>}
                <button className="pt-btn pt-btn--block" type="submit" disabled={loading}>
                    {loading ? t('forgot.sending') : t('forgot.sendBtn')}
                </button>
                <div className="pt-auth-foot">
                    <Link to="/login" className="pt-link">{t('forgot.backToLogin')}</Link>
                </div>
            </form>
        </AuthShell>
    );
}
