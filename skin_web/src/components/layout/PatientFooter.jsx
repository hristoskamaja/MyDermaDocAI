import { useLang } from '../../context/LanguageContext';
import './PatientFooter.css';

export default function PatientFooter() {
    const { t } = useLang();
    const year = new Date().getFullYear();

    return (
        <footer className="patient-footer">
            <div className="patient-footer-inner">
                <p className="patient-footer-disclaimer">{t('disclaimer.text')}</p>
                <span className="patient-footer-copy">© {year} DermaScanAI</span>
            </div>
        </footer>
    );
}
