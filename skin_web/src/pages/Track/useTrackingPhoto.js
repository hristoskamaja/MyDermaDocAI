import { useEffect, useState } from 'react';
import { trackingAPI } from '../../services/api';

// Check-in photos are private: they can only be fetched with the Bearer token,
// so a plain <img src="/api/..."> would 401. This hook downloads the photo as a
// blob and exposes a blob: URL, revoked when the date changes or on unmount.
export default function useTrackingPhoto(day, enabled = true) {
    const [url, setUrl] = useState(null);
    const [loading, setLoading] = useState(false);

    useEffect(() => {
        if (!day || !enabled) {
            setUrl(null);
            return undefined;
        }
        let cancelled = false;
        let objectUrl = null;
        setLoading(true);
        trackingAPI.getPhoto(day)
            .then((res) => {
                if (cancelled) return;
                objectUrl = URL.createObjectURL(res.data);
                setUrl(objectUrl);
            })
            .catch(() => { if (!cancelled) setUrl(null); })
            .finally(() => { if (!cancelled) setLoading(false); });

        return () => {
            cancelled = true;
            if (objectUrl) URL.revokeObjectURL(objectUrl);
        };
    }, [day, enabled]);

    return { url, loading };
}
