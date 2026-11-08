import { Moon, Sun } from 'lucide-react';
import { useLang } from '../../context/LanguageContext';
import { useTheme } from '../../context/ThemeContext';

// EN/MK pill + dark-mode toggle, shared by the patient navbar and the
// logged-out auth pages (Login, Register, Forgot/Reset password).
export default function AuthToolbar() {
    const { lang, setLang, t } = useLang();
    const { isDark, toggleTheme } = useTheme();

    return (
        <div className="patient-toolbar">
            <div className="patient-lang-switch" role="group" aria-label={t('nav.language')}>
                <button
                    type="button"
                    className={`patient-lang-btn${lang === 'en' ? ' patient-lang-btn--active' : ''}`}
                    onClick={() => setLang('en')}
                >EN</button>
                <button
                    type="button"
                    className={`patient-lang-btn${lang === 'mk' ? ' patient-lang-btn--active' : ''}`}
                    onClick={() => setLang('mk')}
                >MK</button>
            </div>
            <button
                type="button"
                className="patient-icon-btn"
                onClick={toggleTheme}
                title={isDark ? t('settings.lightMode') : t('settings.darkMode')}
                aria-label={isDark ? t('settings.lightMode') : t('settings.darkMode')}
            >
                {isDark ? <Sun size={17} strokeWidth={1.8} /> : <Moon size={17} strokeWidth={1.8} />}
            </button>
        </div>
    );
}
