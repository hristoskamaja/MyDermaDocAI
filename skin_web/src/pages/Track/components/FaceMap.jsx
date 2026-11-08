import { useLang } from '../../../context/LanguageContext';

// Simple schematic face; each zone toggles one breakout area. The chips below
// the drawing do the same, so the map is never the only way to pick an area.
const ZONES = {
    forehead:    { shape: 'ellipse', cx: 100, cy: 58,  rx: 52, ry: 20 },
    nose:        { shape: 'ellipse', cx: 100, cy: 112, rx: 12, ry: 26 },
    left_cheek:  { shape: 'ellipse', cx: 60,  cy: 128, rx: 22, ry: 24 },
    right_cheek: { shape: 'ellipse', cx: 140, cy: 128, rx: 22, ry: 24 },
    chin:        { shape: 'ellipse', cx: 100, cy: 178, rx: 24, ry: 14 },
    jawline:     { shape: 'path', d: 'M42 150 Q52 190 86 202 M158 150 Q148 190 114 202' },
};

export default function FaceMap({ areas, selected, onToggle }) {
    const { t } = useLang();
    return (
        <div className="tr-facemap-wrap">
            <svg viewBox="0 0 200 230" className="tr-facemap" role="group" aria-label={t('track.checkin.areasTitle')}>
                <ellipse cx="100" cy="120" rx="68" ry="96" className="tr-face-outline" />
                {areas.map((key) => {
                    const zone = ZONES[key];
                    const active = selected.includes(key);
                    const props = {
                        className: `tr-zone${active ? ' tr-zone--on' : ''}`,
                        role: 'button',
                        tabIndex: 0,
                        'aria-pressed': active,
                        'aria-label': t(`track.areas.${key}`),
                        onClick: () => onToggle(key),
                        onKeyDown: (e) => {
                            if (e.key === 'Enter' || e.key === ' ') {
                                e.preventDefault();
                                onToggle(key);
                            }
                        },
                    };
                    return zone.shape === 'ellipse'
                        ? <ellipse key={key} cx={zone.cx} cy={zone.cy} rx={zone.rx} ry={zone.ry} {...props} />
                        : <path key={key} d={zone.d} {...props} className={`${props.className} tr-zone--line`} />;
                })}
            </svg>
            <div className="tr-chips">
                {areas.map((key) => (
                    <button
                        key={key}
                        type="button"
                        className={`tr-chip${selected.includes(key) ? ' tr-chip--on' : ''}`}
                        aria-pressed={selected.includes(key)}
                        onClick={() => onToggle(key)}
                    >
                        {t(`track.areas.${key}`)}
                    </button>
                ))}
            </div>
        </div>
    );
}
