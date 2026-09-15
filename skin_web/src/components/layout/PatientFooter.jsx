import { Link } from 'react-router-dom';
import { useLang } from '../../context/LanguageContext';
import './PatientFooter.css';

export default function PatientFooter() {
    const { t } = useLang();
    const year = new Date().getFullYear();

    return (
        <footer className="patient-footer">
            <div className="patient-footer-inner">
                <div className="patient-footer-brand">
                    <div className="patient-brand-icon">D</div>
                    <span className="patient-brand-name">DermaScanAI</span>
                </div>

                <nav className="patient-footer-links">
                    <Link to="/scan">{t('scan.title')}</Link>
                    <Link to="/history">{t('history.title')}</Link>
                    <Link to="/find-dermatologist">{t('home.findDermatologist')}</Link>
                </nav>

                <span className="patient-footer-copy">© {year} DermaScanAI</span>
            </div>
            <p className="patient-footer-disclaimer">{t('disclaimer.text')}</p>
        </footer>
    );
}
