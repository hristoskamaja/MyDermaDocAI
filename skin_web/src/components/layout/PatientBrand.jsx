// Small brand mark shared by the patient navbar, footer and auth pages.
export default function PatientBrand({ size = 30 }) {
    return (
        <span
            className="patient-brand-icon"
            style={{ width: size, height: size }}
            aria-hidden="true"
        >
            <span className="patient-brand-dot" />
        </span>
    );
}
