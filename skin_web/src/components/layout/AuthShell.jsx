import PatientBrand from './PatientBrand';
import AuthToolbar from './AuthToolbar';
import './AuthShell.css';

// Centered card on the cream background, shared by Login, Register and the
// two password-reset pages. EN/MK pill + dark toggle sit top-right.
export default function AuthShell({ children }) {
    return (
        <div className="pt-auth-page theme-patient">
            <div className="pt-auth-top">
                <AuthToolbar />
            </div>
            <div className="pt-auth-brand">
                <PatientBrand size={34} />
                <span>DermaScan<span className="pt-auth-brand-ai">AI</span></span>
            </div>
            <div className="pt-card pt-auth-card">{children}</div>
        </div>
    );
}
