import { useState, useEffect } from 'react';
import { Lock, Check, Eye, EyeOff } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { jwtAPI } from '../../services/api';
import { useLang } from '../../context/LanguageContext';
import PageHeroWave from '../../components/decor/PageHeroWave';
import './Profile.css';

export default function Profile() {
    const { user } = useAuth();
    const { t }    = useLang();

    const [fullName, setFullName] = useState('');
    const [email,    setEmail]    = useState('');
    const [role,     setRole]     = useState('');
    const [loading,  setLoading]  = useState(true);

    const [currentPw, setCurrentPw] = useState('');
    const [newPw,     setNewPw]     = useState('');
    const [confirmPw, setConfirmPw] = useState('');
    const [showCurr,  setShowCurr]  = useState(false);
    const [showNew,   setShowNew]   = useState(false);
    const [showConf,  setShowConf]  = useState(false);
    const [pwError,   setPwError]   = useState('');
    const [pwSaved,   setPwSaved]   = useState(false);
    const [pwLoading, setPwLoading] = useState(false);

    useEffect(() => {
        const load = async () => {
            try {
                const res = await jwtAPI.me();
                setFullName(res.data.full_name || '');
                setEmail(res.data.email || '');
                setRole(res.data.role || '');
            } catch (err) {
                setFullName(user?.full_name || '');
                setEmail(user?.email || '');
                setRole(user?.role || '');
            } finally {
                setLoading(false);
            }
        };
        load();
    }, []);

    const initial = fullName?.[0]?.toUpperCase() || 'A';
    const roleLabel = role === 'ADMIN' ? t('users.admin') : t('users.user');

    const handlePasswordChange = async () => {
        setPwError('');
        if (!currentPw || !newPw || !confirmPw) { setPwError(t('profile.pwErrorRequired')); return; }
        if (newPw.length < 6)                   { setPwError(t('profile.pwErrorLength'));   return; }
        if (newPw !== confirmPw)                 { setPwError(t('profile.pwErrorMatch'));    return; }
        setPwLoading(true);
        try {
            await jwtAPI.changePassword({ old_password: currentPw, new_password: newPw });
            setPwSaved(true);
            setCurrentPw(''); setNewPw(''); setConfirmPw('');
            setTimeout(() => setPwSaved(false), 2500);
        } catch (err) {
            setPwError(err.response?.data?.detail || err.response?.data?.old_password?.[0] || 'Failed to change password.');
        } finally {
            setPwLoading(false);
        }
    };

    if (loading) return <div className="dash-loading">{t('common.loading')}</div>;

    return (
        <div className="profile-page">
            <div className="page-hero-band">
                <PageHeroWave />
                <div className="page-hero-inner">
                    <div className="page-header">
                        <div>
                            <h1 className="page-title">{t('profile.title')}</h1>
                            <p className="page-subtitle">{t('profile.subtitle')}</p>
                        </div>
                    </div>
                </div>
            </div>

            <div className="profile-grid">

                {/* ── Identity card ────────────────────────────────────────────── */}
                <div className="profile-card profile-card--identity">
                    <div className="profile-avatar">{initial}</div>
                    <div className="profile-name">{fullName || '—'}</div>
                    <div className="profile-email">{email || '—'}</div>
                    <span className={`role-pill ${role === 'ADMIN' ? 'role-pill--admin' : 'role-pill--user'}`}>{roleLabel}</span>
                </div>

                {/* ── Change password card ─────────────────────────────────────── */}
                <div className="profile-card">
                    <div className="profile-card-header">
                        <h2 className="profile-card-title">{t('profile.changePassword')}</h2>
                        <p className="profile-card-desc">{t('settings.securityDesc')}</p>
                    </div>
                    <div className="profile-form">
                        <div className="form-field">
                            <label className="form-label">{t('profile.currentPw')}</label>
                            <div className="pw-input-wrap">
                                <input className="form-input" type={showCurr ? 'text' : 'password'}
                                       value={currentPw} onChange={e => setCurrentPw(e.target.value)} placeholder="••••••••" />
                                <button className="pw-eye" onClick={() => setShowCurr(v => !v)} type="button">
                                    {showCurr ? <EyeOff size={16} strokeWidth={1.8} /> : <Eye size={16} strokeWidth={1.8} />}
                                </button>
                            </div>
                        </div>
                        <div className="form-field">
                            <label className="form-label">{t('profile.newPw')}</label>
                            <div className="pw-input-wrap">
                                <input className="form-input" type={showNew ? 'text' : 'password'}
                                       value={newPw} onChange={e => setNewPw(e.target.value)} placeholder="••••••••" />
                                <button className="pw-eye" onClick={() => setShowNew(v => !v)} type="button">
                                    {showNew ? <EyeOff size={16} strokeWidth={1.8} /> : <Eye size={16} strokeWidth={1.8} />}
                                </button>
                            </div>
                        </div>
                        <div className="form-field">
                            <label className="form-label">{t('profile.confirmPw')}</label>
                            <div className="pw-input-wrap">
                                <input className="form-input" type={showConf ? 'text' : 'password'}
                                       value={confirmPw} onChange={e => setConfirmPw(e.target.value)} placeholder="••••••••" />
                                <button className="pw-eye" onClick={() => setShowConf(v => !v)} type="button">
                                    {showConf ? <EyeOff size={16} strokeWidth={1.8} /> : <Eye size={16} strokeWidth={1.8} />}
                                </button>
                            </div>
                        </div>
                        {pwError && <div className="pw-error">{pwError}</div>}
                        {pwSaved && <div className="pw-success"><Check size={15} strokeWidth={2.5} /> {t('profile.pwSuccess')}</div>}
                        <div>
                            <button className="btn btn--primary" onClick={handlePasswordChange} disabled={pwLoading}>
                                <Lock size={15} strokeWidth={1.8} /> {pwLoading ? 'Saving…' : t('profile.changePwBtn')}
                            </button>
                        </div>
                    </div>
                </div>

            </div>
        </div>
    );
}
