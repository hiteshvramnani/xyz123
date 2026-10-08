import { useState, useEffect, useCallback, useRef } from 'react';
import { createPortal } from 'react-dom';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import {
  listTrails,
  listSubmissions,
  getSubmission,
  listThreads,
  search,
  login,
  logout,
  getCurrentUser,
  isAdmin,
  listUsers,
  updateUserStatus,
  deleteUser,
  submitEvidence,
  finalizeEvidence,
  uploadToS3,
  getBrowserId,
  listMySubmissions,
  addToSubmission as addToSubmissionApi,
} from './lib/api';
import type { Trail, Submission } from './types';

function formatDate(dateStr: string) {
  return new Date(dateStr).toLocaleString('en-IN', {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
}

function formatFileSize(bytes: number): string {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / 1048576).toFixed(1) + ' MB';
}

// ── Map Picker ─────────────────────────────────────────────
function MapPicker({
  coords,
  onCoordsChange,
  searchSuggestions,
  onSuggestionSelect,
}: {
  coords: { lat: string; lon: string } | null;
  onCoordsChange: (c: { lat: string; lon: string }) => void;
  searchSuggestions: Array<{ lat: string; lon: string; name: string }>;
  onSuggestionSelect: (s: { lat: string; lon: string; name: string }) => void;
}) {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<L.Map | null>(null);
  const markerRef = useRef<L.Marker | null>(null);

  useEffect(() => {
    if (!mapRef.current || mapInstanceRef.current) return;

    const map = L.map(mapRef.current, {
      zoomControl: true,
      attributionControl: false,
    }).setView([20, 0], 2);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
    }).addTo(map);

    mapInstanceRef.current = map;

    // Fix Leaflet marker icons in Vite
    const defaultIcon = L.icon({
      iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
      iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
      shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
      iconSize: [25, 41],
      iconAnchor: [12, 41],
      popupAnchor: [1, -34],
      shadowSize: [41, 41],
    });
    L.Marker.prototype.options.icon = defaultIcon;

    map.on('click', (e: L.LeafletMouseEvent) => {
      const { lat, lng } = e.latlng;
      const latStr = lat.toFixed(6);
      const lngStr = lng.toFixed(6);
      onCoordsChange({ lat: latStr, lon: lngStr });
      if (markerRef.current) {
        markerRef.current.setLatLng(e.latlng);
      } else {
        markerRef.current = L.marker(e.latlng, { draggable: true }).addTo(map);
        markerRef.current.on('dragend', () => {
          const m = markerRef.current!.getLatLng();
          onCoordsChange({ lat: m.lat.toFixed(6), lon: m.lng.toFixed(6) });
        });
      }
    });

    return () => {
      map.remove();
      mapInstanceRef.current = null;
      markerRef.current = null;
    };
  }, []);

  useEffect(() => {
    if (coords && mapInstanceRef.current) {
      const lat = parseFloat(coords.lat);
      const lng = parseFloat(coords.lon);
      mapInstanceRef.current.setView([lat, lng], 14);
      if (markerRef.current) {
        markerRef.current.setLatLng([lat, lng]);
      } else {
        markerRef.current = L.marker([lat, lng], { draggable: true }).addTo(mapInstanceRef.current);
        markerRef.current.on('dragend', () => {
          const m = markerRef.current!.getLatLng();
          onCoordsChange({ lat: m.lat.toFixed(6), lon: m.lng.toFixed(6) });
        });
      }
    }
  }, [coords]);

  // Show suggestions as markers on the map
  useEffect(() => {
    if (!mapInstanceRef.current) return;
    // Clear any temp suggestion markers
    const map = mapInstanceRef.current;
    (map as any)._suggestionMarkers?.forEach((m: L.Marker) => m.remove());
    (map as any)._suggestionMarkers = [];

    if (searchSuggestions.length > 0) {
      searchSuggestions.forEach((s) => {
        const lat = parseFloat(s.lat);
        const lng = parseFloat(s.lon);
        const marker = L.circleMarker([lat, lng], {
          radius: 6,
          color: '#3b82f6',
          fillColor: '#3b82f6',
          fillOpacity: 0.6,
        }).addTo(map);
        marker.on('click', () => {
          onSuggestionSelect(s);
        });
        (map as any)._suggestionMarkers.push(marker);
      });

      // Fit bounds to show all suggestions
      const group = L.featureGroup((map as any)._suggestionMarkers);
      map.fitBounds(group.getBounds().pad(0.2));
    }
  }, [searchSuggestions]);

  return (
    <div
      ref={mapRef}
      className="w-full h-48 rounded border border-gray-700 mb-1"
      style={{ zIndex: 1 }}
    />
  );
}

// ── Public Evidence Submission Portal ─────────────────────
function PublicEvidencePortal({ onAdminLogin }: { onAdminLogin: () => void }) {
  const [view, setView] = useState<'form' | 'uploading' | 'done' | 'my-submissions' | 'submission'>('form');
  const [title, setTitle] = useState('');
  const [files, setFiles] = useState<File[]>([]);
  const [error, setError] = useState('');
  const [progress, setProgress] = useState('');
  const [checkTitle, setCheckTitle] = useState(false);
  const [checkImage, setCheckImage] = useState(false);
  const [checkVideo, setCheckVideo] = useState(false);
  const [checkPhone, setCheckPhone] = useState(false);
  const [checkLocation, setCheckLocation] = useState(false);
  const [phoneNumber, setPhoneNumber] = useState('');
  const [manualLocation, setManualLocation] = useState('');
  const [manualLocationCoords, setManualLocationCoords] = useState<{ lat: string; lon: string } | null>(null);
  const [locationSuggestions, setLocationSuggestions] = useState<Array<{ lat: string; lon: string; name: string }>>([]);
  const [locationLoading, setLocationLoading] = useState(false);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const locationInputRef = useRef<HTMLInputElement>(null);
  const locationDebounceRef = useRef<number>(0);
  const [mySubmissions, setMySubmissions] = useState<any[]>([]);
  const [selectedSubmissionId, setSelectedSubmissionId] = useState<string | null>(null);
  const imageInputRef = useRef<HTMLInputElement>(null);
  const videoInputRef = useRef<HTMLInputElement>(null);
  const browserId = getBrowserId();

  // Check if all checked fields are filled
  const imageFiles = files.filter(f => f.type.startsWith('image/'));
  const videoFiles = files.filter(f => f.type.startsWith('video/'));
  const canSubmit = (
    (!checkTitle || title.trim()) &&
    (!checkImage || imageFiles.length > 0) &&
    (!checkVideo || videoFiles.length > 0) &&
    (!checkPhone || phoneNumber.trim()) &&
    (!checkLocation || (manualLocationCoords && manualLocation.trim()))
  );
  const hasAnyChecked = checkTitle || checkImage || checkVideo || checkPhone || checkLocation;

  // Debounced Nominatim search
  const searchLocation = useCallback((query: string) => {
    if (query.length < 2) {
      setLocationSuggestions([]);
      return;
    }
    setLocationLoading(true);
    fetch(`https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(query)}&format=json&limit=5&addressdetails=1`, {
      headers: { 'User-Agent': 'DataCollectionPortal/1.0' }
    })
      .then((res) => res.json())
      .then((data: any[]) => {
        const suggestions = data.map((f) => ({
          lat: parseFloat(f.lat).toFixed(6),
          lon: parseFloat(f.lon).toFixed(6),
          name: f.display_name,
        }));
        setLocationSuggestions(suggestions);
        setLocationLoading(false);
        if (suggestions.length > 0) setShowSuggestions(true);
      })
      .catch(() => {
        setLocationLoading(false);
        setLocationSuggestions([]);
      });
  }, []);

  // Cleanup debounce on unmount
  useEffect(() => {
    return () => {
      if (locationDebounceRef.current) clearTimeout(locationDebounceRef.current);
    };
  }, []);

  // Close suggestions on click outside
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (locationInputRef.current && !locationInputRef.current.contains(e.target as Node)) {
        setShowSuggestions(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const handleFilesSelected = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      setFiles(prev => [...prev, ...Array.from(e.target.files)]);
    }
  };

  const loadMySubmissions = async () => {
    try {
      const r = await listMySubmissions(browserId);
      setMySubmissions(r.data || []);
    } catch {
      setMySubmissions([]);
    }
  };

  const handleSubmit = async () => {
    if (!hasAnyChecked || !canSubmit) return;
    setError('');
    setLocationSuggestions([]);
    setShowSuggestions(false);

    try {
      // Capture device info, timezone, and GPS location
      setProgress('Collecting device info...');
      const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
      const deviceInfo = navigator.userAgent;
      let location = '';
      try {
        const pos = await new Promise<GeolocationPosition>((resolve, reject) => {
          navigator.geolocation.getCurrentPosition(resolve, reject, { timeout: 5000, enableHighAccuracy: false });
        });
        location = `${pos.coords.latitude.toFixed(6)},${pos.coords.longitude.toFixed(6)}`;
      } catch {
        // Location not available, that's fine
      }

      const manualLocationStr = manualLocationCoords
        ? `${manualLocationCoords.lat},${manualLocationCoords.lon}`
        : undefined;

      // Step 1: Create submission and get upload URLs
      setProgress('Creating submission...');
      const fileInputs = files.map((f) => ({
        mimeType: f.type,
        fileSizeBytes: f.size,
        fileName: f.name,
      }));

      const r = await submitEvidence({
        title: title.trim(),
        files: fileInputs,
        location,
        deviceInfo,
        timezone,
        browserId,
        phoneNumber: phoneNumber.trim() || undefined,
        manualLocation: manualLocationStr,
      });

      const uploadUrls = r.data?.uploadUrls || [];
      const submissionId = r.data?.submissionId;

      if (files.length > 0) {
        setView('uploading');

        // Step 2: Upload each file via presigned URL
        const s3Keys: string[] = [];
        for (let i = 0; i < files.length; i++) {
          setProgress(`Uploading file ${i + 1}/${files.length}...`);
          const urlData = uploadUrls[i];
          await uploadToS3(urlData.uploadUrl, files[i]);
          s3Keys.push(urlData.s3Key);
        }

        // Step 3: Finalize
        setProgress('Finalizing...');
        await finalizeEvidence(submissionId, s3Keys);
      }

      setView('done');
    } catch (e: any) {
      setError(e.message || 'Something went wrong');
      setView('form');
    }
  };

  if (view === 'done') {
    return (
      <div className="min-h-screen bg-gray-950 text-gray-100 flex items-center justify-center px-4">
        <div className="max-w-md w-full text-center">
          <div className="bg-gray-900 border border-gray-800 rounded-lg p-8">
            <div className="text-5xl mb-4">✓</div>
            <h2 className="text-2xl font-bold text-gray-100 mb-2">Evidence Submitted</h2>
            <p className="text-gray-400 mb-6">
              Your submission has been received successfully. Thank you for contributing.
            </p>
            <div className="flex gap-3 justify-center">
              <button
                onClick={() => {
                  setView('form');
                  setTitle('');
                  setFiles([]);
                  setPhoneNumber('');
                  setCheckTitle(false);
                  setCheckImage(false);
                  setCheckVideo(false);
                  setCheckPhone(false);
                  setCheckLocation(false);
                  setManualLocation('');
                  setManualLocationCoords(null);
                  setLocationSuggestions([]);
                }}
                className="bg-blue-600 hover:bg-blue-500 text-white px-6 py-2 rounded text-sm font-medium"
              >
                Submit Another
              </button>
              <button
                onClick={() => {
                  loadMySubmissions();
                  setView('my-submissions');
                }}
                className="bg-gray-800 hover:bg-gray-700 text-white px-6 py-2 rounded text-sm font-medium"
              >
                My Submissions
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-950 text-gray-100">
      {/* Header */}
      <header className="border-b border-gray-800 bg-gray-950 px-6 py-4">
        <div className="max-w-6xl mx-auto flex items-center justify-between">
          <button
            onClick={() => setView('form')}
            className="text-lg font-bold text-gray-100 hover:text-white"
          >
            Data Collection Platform
          </button>
          <div className="flex items-center gap-4">
            <button
              onClick={() => {
                loadMySubmissions();
                setView('my-submissions');
              }}
              className="text-sm text-gray-500 hover:text-gray-300"
            >
              My Submissions
            </button>
            <button
              onClick={onAdminLogin}
              className="text-sm text-gray-500 hover:text-gray-300"
            >
              Admin Login
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-2xl mx-auto px-6 py-12">
        {view === 'form' && (
          <div>
            <h2 className="text-2xl font-bold text-gray-100 mb-6">New Submission</h2>

            {error && (
              <div className="bg-red-900/50 border border-red-700 text-red-300 px-4 py-3 rounded mb-4 text-sm">
                {error}
              </div>
            )}

            <div className="space-y-5">
              {/* Field Checkboxes */}
              <div className="bg-gray-900 border border-gray-800 rounded-lg p-4">
                <p className="text-xs text-gray-500 mb-3">Select what you want to include in this submission. A checked field is required.</p>
                <div className="grid grid-cols-3 gap-2">
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={checkTitle}
                      onChange={() => setCheckTitle(!checkTitle)}
                      className="form-checkbox rounded border-gray-600 bg-gray-800 text-blue-600 focus:ring-blue-500 focus:ring-offset-0 w-4 h-4"
                    />
                    <span className={`text-sm ${checkTitle ? 'text-gray-200' : 'text-gray-500'}`}>Title</span>
                    {checkTitle && (title.trim() ? <span className="text-green-400 text-xs">✓</span> : <span className="text-red-400 text-xs">●</span>)}
                  </label>
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={checkImage}
                      onChange={() => setCheckImage(!checkImage)}
                      className="form-checkbox rounded border-gray-600 bg-gray-800 text-blue-600 focus:ring-blue-500 focus:ring-offset-0 w-4 h-4"
                    />
                    <span className={`text-sm ${checkImage ? 'text-gray-200' : 'text-gray-500'}`}>Image</span>
                    {checkImage && (imageFiles.length > 0 ? <span className="text-green-400 text-xs">✓</span> : <span className="text-red-400 text-xs">●</span>)}
                  </label>
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={checkVideo}
                      onChange={() => setCheckVideo(!checkVideo)}
                      className="form-checkbox rounded border-gray-600 bg-gray-800 text-blue-600 focus:ring-blue-500 focus:ring-offset-0 w-4 h-4"
                    />
                    <span className={`text-sm ${checkVideo ? 'text-gray-200' : 'text-gray-500'}`}>Video</span>
                    {checkVideo && (videoFiles.length > 0 ? <span className="text-green-400 text-xs">✓</span> : <span className="text-red-400 text-xs">●</span>)}
                  </label>
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={checkPhone}
                      onChange={() => setCheckPhone(!checkPhone)}
                      className="form-checkbox rounded border-gray-600 bg-gray-800 text-blue-600 focus:ring-blue-500 focus:ring-offset-0 w-4 h-4"
                    />
                    <span className={`text-sm ${checkPhone ? 'text-gray-200' : 'text-gray-500'}`}>Phone Number</span>
                    {checkPhone && (phoneNumber.trim() ? <span className="text-green-400 text-xs">✓</span> : <span className="text-red-400 text-xs">●</span>)}
                  </label>
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={checkLocation}
                      onChange={() => setCheckLocation(!checkLocation)}
                      className="form-checkbox rounded border-gray-600 bg-gray-800 text-blue-600 focus:ring-blue-500 focus:ring-offset-0 w-4 h-4"
                    />
                    <span className={`text-sm ${checkLocation ? 'text-gray-200' : 'text-gray-500'}`}>Location</span>
                    {checkLocation && ((manualLocationCoords && manualLocation.trim()) ? <span className="text-green-400 text-xs">✓</span> : <span className="text-red-400 text-xs">●</span>)}
                  </label>
                </div>
              </div>

              {/* Title Input */}
              {checkTitle && (
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Title</label>
                  <textarea
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    placeholder="Brief description of the evidence..."
                    rows={3}
                    className="w-full bg-gray-900 text-gray-200 border border-gray-700 rounded px-3 py-2 text-sm focus:outline-none focus:border-blue-500 placeholder-gray-600 resize-none"
                  />
                </div>
              )}

              {/* Image Input */}
              {checkImage && (
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Image</label>
                  <input
                    ref={imageInputRef}
                    type="file"
                    multiple
                    accept="image/*"
                    onChange={handleFilesSelected}
                    className="hidden"
                  />
                  <button
                    type="button"
                    onClick={() => imageInputRef.current?.click()}
                    className="border-2 border-dashed border-gray-700 hover:border-gray-600 rounded-lg p-6 text-center transition-colors w-full"
                  >
                    <div className="text-2xl mb-1">+</div>
                    <p className="text-gray-400 text-sm">Select Photos</p>
                  </button>
                  {imageFiles.length > 0 && (
                    <div className="mt-2 space-y-2">
                      {imageFiles.map((f, i) => (
                        <div key={i} className="bg-gray-900 border border-gray-800 rounded p-3 flex items-center justify-between">
                          <div className="flex items-center gap-3">
                            <span className="text-lg">🖼</span>
                            <div>
                              <p className="text-sm text-gray-200 truncate max-w-xs">{f.name}</p>
                              <p className="text-xs text-gray-500">{formatFileSize(f.size)}</p>
                            </div>
                          </div>
                          <button
                            onClick={() => setFiles(files.filter(x => x !== f))}
                            className="text-gray-500 hover:text-red-400 text-sm"
                          >
                            Remove
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}

              {/* Video Input */}
              {checkVideo && (
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Video</label>
                  <input
                    ref={videoInputRef}
                    type="file"
                    multiple
                    accept="video/*"
                    onChange={handleFilesSelected}
                    className="hidden"
                  />
                  <button
                    type="button"
                    onClick={() => videoInputRef.current?.click()}
                    className="border-2 border-dashed border-gray-700 hover:border-gray-600 rounded-lg p-6 text-center transition-colors w-full"
                  >
                    <div className="text-2xl mb-1">+</div>
                    <p className="text-gray-400 text-sm">Select Videos</p>
                  </button>
                  {videoFiles.length > 0 && (
                    <div className="mt-2 space-y-2">
                      {videoFiles.map((f, i) => (
                        <div key={i} className="bg-gray-900 border border-gray-800 rounded p-3 flex items-center justify-between">
                          <div className="flex items-center gap-3">
                            <span className="text-lg">🎬</span>
                            <div>
                              <p className="text-sm text-gray-200 truncate max-w-xs">{f.name}</p>
                              <p className="text-xs text-gray-500">{formatFileSize(f.size)}</p>
                            </div>
                          </div>
                          <button
                            onClick={() => setFiles(files.filter(x => x !== f))}
                            className="text-gray-500 hover:text-red-400 text-sm"
                          >
                            Remove
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}

              {/* Phone Number Input */}
              {checkPhone && (
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Phone Number</label>
                  <input
                    value={phoneNumber}
                    onChange={(e) => setPhoneNumber(e.target.value)}
                    placeholder="+1 234 567 8900"
                    className="w-full bg-gray-900 text-gray-200 border border-gray-700 rounded px-3 py-2 text-sm focus:outline-none focus:border-blue-500 placeholder-gray-600"
                  />
                </div>
              )}

              {/* Location Input */}
              {checkLocation && (
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Location</label>
                  <div className="relative">
                    <input
                      ref={locationInputRef}
                      value={manualLocation}
                      onChange={(e) => {
                        const val = e.target.value;
                        setManualLocation(val);
                        setManualLocationCoords(null);
                        setShowSuggestions(false);
                        if (locationDebounceRef.current) clearTimeout(locationDebounceRef.current);
                        locationDebounceRef.current = window.setTimeout(() => {
                          searchLocation(val);
                        }, 800);
                      }}
                      onFocus={() => {
                        if (locationSuggestions.length > 0) setShowSuggestions(true);
                      }}
                      placeholder="Search for a place (e.g. Central Park, NYC)"
                      className="w-full bg-gray-900 text-gray-200 border border-gray-700 rounded px-3 py-2 text-sm focus:outline-none focus:border-blue-500 placeholder-gray-600 mb-1"
                    />
                    <MapPicker
                      coords={manualLocationCoords}
                      onCoordsChange={(c) => {
                        setManualLocationCoords(c);
                      }}
                      searchSuggestions={locationSuggestions}
                      onSuggestionSelect={(s) => {
                        setManualLocation(s.name);
                        setManualLocationCoords({ lat: s.lat, lon: s.lon });
                        setLocationSuggestions([]);
                        setShowSuggestions(false);
                      }}
                    />
                    {showSuggestions && locationSuggestions.length > 0 && locationInputRef.current && (
                      createPortal(
                        <div
                            style={{
                              position: 'fixed',
                              top: locationInputRef.current.getBoundingClientRect().bottom + 4,
                              left: locationInputRef.current.getBoundingClientRect().left,
                              width: locationInputRef.current.getBoundingClientRect().width,
                              zIndex: 99999,
                            }}
                            className="bg-gray-900 border border-gray-700 rounded shadow-lg max-h-48 overflow-y-auto"
                          >
                            {locationSuggestions.map((s, i) => (
                              <button
                                key={i}
                                type="button"
                                onMouseDown={() => {
                                  setManualLocation(s.name);
                                  setManualLocationCoords({ lat: s.lat, lon: s.lon });
                                  setLocationSuggestions([]);
                                  setShowSuggestions(false);
                                }}
                                className="w-full text-left px-3 py-2 text-sm text-gray-200 hover:bg-gray-800 first:rounded-t last:rounded-b"
                              >
                                {s.name}
                              </button>
                            ))}
                          </div>,
                        document.body
                      )
                    )}
                    {locationLoading && (
                      <div className="absolute right-3 top-2 text-xs text-gray-500">Searching...</div>
                    )}
                  </div>
                  {manualLocationCoords && (
                    <p className="text-xs text-gray-500 mt-1">
                      ✓ {manualLocationCoords.lat}, {manualLocationCoords.lon}
                    </p>
                  )}
                </div>
              )}

              {/* Submit Button */}
              <button
                onClick={handleSubmit}
                disabled={!hasAnyChecked || !canSubmit}
                className="w-full bg-blue-600 hover:bg-blue-500 disabled:opacity-40 disabled:cursor-not-allowed text-white px-6 py-3 rounded text-sm font-medium"
              >
                Submit Evidence
              </button>
            </div>
          </div>
        )}

        {view === 'uploading' && (
          <div className="text-center py-12">
            <div className="text-4xl mb-4 animate-spin">⟳</div>
            <h2 className="text-xl font-bold text-gray-100 mb-2">Submitting Evidence</h2>
            <p className="text-gray-400">{progress}</p>
          </div>
        )}

        {view === 'my-submissions' && (
          <div>
            <button
              onClick={() => setView('form')}
              className="text-gray-400 hover:text-gray-300 text-sm mb-6"
            >
              ← Back
            </button>

            <h2 className="text-2xl font-bold text-gray-100 mb-6">My Submissions</h2>

            {mySubmissions.length === 0 ? (
              <div className="text-gray-500 text-center py-8">No submissions yet.</div>
            ) : (
              <div className="grid gap-3">
                {mySubmissions.map((s) => {
                  const titleText = s.what?.trim()
                    ? s.what.length > 120 ? s.what.slice(0, 120) + '...' : s.what
                    : '[No title]';
                  return (
                    <div key={s.id} className="bg-gray-900 border border-gray-800 rounded-lg p-4 hover:border-gray-700 transition-colors">
                      <button
                        onClick={() => {
                          setSelectedSubmissionId(s.id);
                          setView('submission');
                        }}
                        className={`text-sm text-left w-full ${!s.what?.trim() ? 'text-gray-500' : 'text-blue-400 hover:text-blue-300'}`}
                      >
                        {titleText}
                      </button>
                      <div className="flex items-center gap-3 mt-2 text-xs text-gray-500">
                        <span>{formatDate(s.when)}</span>
                        <span>{s.mediaCount || 0} files</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}

        {view === 'submission' && selectedSubmissionId && (
          <SubmissionDetailView
            id={selectedSubmissionId}
            onBack={() => setView('my-submissions')}
          />
        )}
      </main>
    </div>
  );
}

// ── Login Page ────────────────────────────────────────────
function LoginPage({ onSuccess, onBack }: { onSuccess: () => void; onBack: () => void }) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      await login(username, password);
      onSuccess();
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-950 text-gray-100 flex items-center justify-center px-4">
      <div className="max-w-md w-full">
        <div className="text-center mb-8">
          <button onClick={onBack} className="text-gray-500 hover:text-gray-300 text-sm mb-4">
            ← Back to Submit
          </button>
          <h1 className="text-3xl font-bold text-gray-100">Admin Login</h1>
        </div>
        <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
          {error && (
            <div className="bg-red-900/50 border border-red-700 text-red-300 px-3 py-2 rounded mb-4 text-sm">
              {error}
            </div>
          )}
          <form onSubmit={handleSubmit}>
            <div className="mb-3">
              <label className="block text-sm text-gray-400 mb-1">Username</label>
              <input
                type="text"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="Enter username..."
                className="w-full bg-gray-950 text-gray-200 border border-gray-700 rounded px-3 py-2 text-sm focus:outline-none focus:border-blue-500 placeholder-gray-600"
              />
            </div>
            <div className="mb-4">
              <label className="block text-sm text-gray-400 mb-1">Password</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Enter password..."
                className="w-full bg-gray-950 text-gray-200 border border-gray-700 rounded px-3 py-2 text-sm focus:outline-none focus:border-blue-500 placeholder-gray-600"
              />
            </div>
            <button
              type="submit"
              disabled={loading || !username.trim() || !password}
              className="w-full bg-blue-600 hover:bg-blue-500 disabled:opacity-40 disabled:cursor-not-allowed text-white px-4 py-2 rounded text-sm font-medium"
            >
              {loading ? 'Signing in...' : 'Sign In'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}

// ── Submission Part Card ───────────────────────────────────
function SubmissionPartCard({
  partIndex,
  partTitle,
  partDate,
  partPhoneNumber,
  partLocation,
  media,
  mediaUrls,
  isAdminView,
  isOriginal,
}: {
  partIndex: number;
  partTitle?: string;
  partDate?: string;
  partPhoneNumber?: string;
  partLocation?: string;
  media: any[];
  mediaUrls: Record<string, string>;
  isAdminView: boolean;
  isOriginal: boolean;
}) {
  return (
    <div className="bg-gray-900 border border-gray-800 rounded-lg p-5 mb-4">
      <div className="flex items-center gap-3 mb-3">
        <span className="text-xs font-medium px-2 py-0.5 rounded bg-gray-800 text-gray-400">
          {isOriginal ? 'Original' : `Addition ${partIndex}`}
        </span>
        {partDate && <span className="text-xs text-gray-500">{formatDate(partDate)}</span>}
      </div>

      {partTitle ? (
        <div className="mb-3">
          <h3 className="text-sm font-medium text-gray-400 mb-1">Title</h3>
          <p className="text-gray-200 text-sm whitespace-pre-wrap">{partTitle}</p>
        </div>
      ) : (isOriginal && !media.length && !partPhoneNumber && !partLocation) && (
        <p className="text-gray-500 text-sm italic mb-3">No title submitted</p>
      )}

      {partPhoneNumber && (
        <div className="mb-3">
          <span className="text-xs text-gray-500">Phone: </span>
          <span className="text-gray-300 text-sm">{partPhoneNumber}</span>
        </div>
      )}

      {partLocation && (
        <div className="mb-3">
          <span className="text-xs text-gray-500">Location: </span>
          <span className="text-gray-300 text-sm">{partLocation}</span>
          {/^[\-0-9.]+,[\-0-9.]+$/.test(partLocation) && (
            <a
              href={`https://www.google.com/maps?q=${partLocation}`}
              target="_blank"
              rel="noreferrer"
              className="text-xs text-blue-400 hover:text-blue-300 ml-2"
            >
              Open in Maps
            </a>
          )}
        </div>
      )}

      {/* Media attachments */}
      {media.length > 0 && (
        <div>
          <h4 className="text-xs font-medium text-gray-400 mb-2">Attachments ({media.length})</h4>
          <div className="grid gap-2">
            {media.map((m: any) => {
              const streamUrl = mediaUrls[m.id];
              if (m.mediaType === 'IMAGE' && streamUrl) {
                return (
                  <div key={m.id} className="bg-gray-950 border border-gray-800 rounded p-3">
                    <img
                      src={streamUrl}
                      alt={m.caption || m.mimeType}
                      className="max-h-96 rounded object-contain bg-black mb-2"
                    />
                    <div className="flex items-center justify-between">
                      <p className="text-xs text-gray-500">{m.mimeType} · {formatFileSize(Number(m.fileSizeBytes))}</p>
                      <a href={streamUrl} target="_blank" rel="noreferrer" className="text-xs text-blue-400 hover:text-blue-300">
                        Open
                      </a>
                    </div>
                  </div>
                );
              }
              if (m.mediaType === 'VIDEO' && streamUrl) {
                return (
                  <div key={m.id} className="bg-gray-950 border border-gray-800 rounded p-3">
                    <video
                      src={streamUrl}
                      controls
                      className="max-h-96 rounded object-contain bg-black mb-2 w-full"
                    />
                    <div className="flex items-center justify-between">
                      <p className="text-xs text-gray-500">{m.mimeType} · {formatFileSize(Number(m.fileSizeBytes))}</p>
                      <a href={streamUrl} target="_blank" rel="noreferrer" className="text-xs text-blue-400 hover:text-blue-300">
                        Open
                      </a>
                    </div>
                  </div>
                );
              }
              return (
                <div key={m.id} className="bg-gray-950 border border-gray-800 rounded p-3">
                  <div className="flex items-center gap-2">
                    <span className="text-lg">
                      {m.mediaType === 'IMAGE' ? '🖼' : m.mediaType === 'VIDEO' ? '🎬' : m.mediaType === 'AUDIO' ? '🎵' : '📎'}
                    </span>
                    <div>
                      <p className="text-sm text-gray-200">{m.caption || m.mimeType}</p>
                      <p className="text-xs text-gray-500">{m.mimeType} · {formatFileSize(Number(m.fileSizeBytes))}</p>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

// ── Submission Detail (shared) ────────────────────────────
function SubmissionDetailView({ id, onBack, isAdminView = false }: { id: string; onBack: () => void; isAdminView?: boolean }) {
  const [submission, setSubmission] = useState<Submission | null>(null);
  const [threads, setThreads] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [mediaUrls, setMediaUrls] = useState<Record<string, string>>({});

  // Add-to-submission state
  const [addTitle, setAddTitle] = useState('');
  const [addFiles, setAddFiles] = useState<File[]>([]);
  const [addError, setAddError] = useState('');
  const [addProgress, setAddProgress] = useState('');
  const [isAdding, setIsAdding] = useState(false);
  const [addCheckTitle, setAddCheckTitle] = useState(false);
  const [addCheckImage, setAddCheckImage] = useState(false);
  const [addCheckVideo, setAddCheckVideo] = useState(false);
  const [addCheckPhone, setAddCheckPhone] = useState(false);
  const [addCheckLocation, setAddCheckLocation] = useState(false);
  const [addPhoneNumber, setAddPhoneNumber] = useState('');
  const [addManualLocation, setAddManualLocation] = useState('');
  const [addManualLocationCoords, setAddManualLocationCoords] = useState<{ lat: string; lon: string } | null>(null);
  const [addLocationSuggestions, setAddLocationSuggestions] = useState<Array<{ lat: string; lon: string; name: string }>>([]);
  const [addLocationLoading, setAddLocationLoading] = useState(false);
  const [addShowSuggestions, setAddShowSuggestions] = useState(false);
  const addLocationInputRef = useRef<HTMLInputElement>(null);
  const addLocationDebounceRef = useRef<number>(0);
  const addImageInputRef = useRef<HTMLInputElement>(null);
  const addVideoInputRef = useRef<HTMLInputElement>(null);

  // Add validation
  const addImageFiles = addFiles.filter(f => f.type.startsWith('image/'));
  const addVideoFiles = addFiles.filter(f => f.type.startsWith('video/'));
  const addCanSubmit = (
    (!addCheckTitle || addTitle.trim()) &&
    (!addCheckImage || addImageFiles.length > 0) &&
    (!addCheckVideo || addVideoFiles.length > 0) &&
    (!addCheckPhone || addPhoneNumber.trim()) &&
    (!addCheckLocation || (addManualLocationCoords && addManualLocation.trim()))
  );
  const addHasAnyChecked = addCheckTitle || addCheckImage || addCheckVideo || addCheckPhone || addCheckLocation;

  const loadSubmission = async () => {
    setLoading(true);
    setError('');
    try {
      const [subData, thrData] = await Promise.all([
        getSubmission(id).then((r: any) => r.data),
        listThreads(id).then((r: any) => r.data || []),
      ]);
      setSubmission(subData);
      setThreads(thrData);
      const viewableMedia = subData?.media?.filter((m: any) => m.mediaType === 'IMAGE' || m.mediaType === 'VIDEO') || [];
      if (viewableMedia.length > 0) {
        const urls: Record<string, string> = {};
        viewableMedia.forEach((m: any) => {
          urls[m.id] = `${window.location.origin}/api/v1/media/${m.id}/stream`;
        });
        setMediaUrls(urls);
      }
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadSubmission();
  }, [id]);

  const handleAddFilesSelected = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      setAddFiles(prev => [...prev, ...Array.from(e.target.files)]);
    }
  };

  const handleAddToSubmission = async () => {
    if (!addHasAnyChecked || !addCanSubmit) return;
    setAddError('');
    setIsAdding(true);
    try {
      const fileInputs = addFiles.map((f) => ({
        mimeType: f.type,
        fileSizeBytes: f.size,
        fileName: f.name,
      }));
      setAddProgress('Creating upload links...');
      const addManualLocationStr = addManualLocationCoords
        ? `${addManualLocationCoords.lat},${addManualLocationCoords.lon}`
        : undefined;
      const r = await addToSubmissionApi(id, addTitle.trim() || undefined, fileInputs, addPhoneNumber.trim() || undefined, addManualLocationStr);
      const uploadUrls = r.data?.uploadUrls || [];
      if (addFiles.length > 0) {
        const s3Keys: string[] = [];
        for (let i = 0; i < addFiles.length; i++) {
          setAddProgress(`Uploading file ${i + 1}/${addFiles.length}...`);
          await uploadToS3(uploadUrls[i].uploadUrl, addFiles[i]);
          s3Keys.push(uploadUrls[i].s3Key);
        }
        setAddProgress('Finalizing...');
        await finalizeEvidence(id, s3Keys);
      }
      setAddTitle('');
      setAddFiles([]);
      setAddPhoneNumber('');
      setAddCheckPhone(false);
      setAddManualLocation('');
      setAddManualLocationCoords(null);
      setAddLocationSuggestions([]);
      setAddProgress('');
      setIsAdding(false);
      await loadSubmission();
    } catch (e: any) {
      setAddError(e.message || 'Failed to add files');
      setIsAdding(false);
      setAddProgress('');
    }
  };

  if (loading) return <div className="text-gray-400">Loading...</div>;
  if (error) return <div className="text-red-400">{error}</div>;
  if (!submission) return <div className="text-gray-500">Not found</div>;

  const metadata = (submission.metadata as Record<string, unknown> | undefined) || {};
  const parts = (metadata.parts as Array<{ title?: string; createdAt: string; phoneNumber?: string; manualLocation?: string }> | undefined) || [];
  const allMedia = submission.media || [];

  // Group media by partIndex
  const mediaByPart: Record<number, any[]> = {};
  allMedia.forEach((m: any) => {
    const idx = m.partIndex ?? 0;
    if (!mediaByPart[idx]) mediaByPart[idx] = [];
    mediaByPart[idx].push(m);
  });

  // Build a unified list of parts with their media
  interface Part {
    index: number;
    title?: string;
    phoneNumber?: string;
    manualLocation?: string;
    date?: string;
    media: any[];
    isOriginal: boolean;
  }

  const unifiedParts: Part[] = [];

  // Original part (index 0)
  const origMedia = mediaByPart[0] || [];
  if (parts[0]) {
    unifiedParts.push({
      index: 0,
      title: parts[0].title,
      phoneNumber: parts[0].phoneNumber,
      manualLocation: parts[0].manualLocation,
      date: parts[0].createdAt,
      media: origMedia,
      isOriginal: true,
    });
  } else if (origMedia.length > 0 || submission.what?.trim()) {
    unifiedParts.push({
      index: 0,
      title: submission.what?.trim() || undefined,
      date: submission.createdAt,
      media: origMedia,
      isOriginal: true,
    });
  }

  // Subsequent parts
  for (let i = 1; i < parts.length; i++) {
    unifiedParts.push({
      index: i,
      title: parts[i].title,
      phoneNumber: parts[i].phoneNumber,
      manualLocation: parts[i].manualLocation,
      date: parts[i].createdAt,
      media: mediaByPart[i] || [],
      isOriginal: false,
    });
  }

  // If no parts array but we have media or a title, show original
  if (unifiedParts.length === 0) {
    unifiedParts.push({
      index: 0,
      title: submission.what?.trim() || undefined,
      date: submission.createdAt,
      media: origMedia,
      isOriginal: true,
    });
  }

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button onClick={onBack} className="text-gray-400 hover:text-gray-300 text-sm">← Back</button>
        <h2 className="text-xl font-semibold text-gray-100">Submission</h2>
      </div>

      {/* Admin-only metadata card */}
      {isAdminView && (
        <div className="bg-gray-900 border border-gray-800 rounded-lg p-5 mb-4">
          <div className="grid grid-cols-2 gap-4 mb-4">
            <div>
              <h3 className="text-sm font-medium text-gray-400 mb-1">When</h3>
              <p className="text-gray-300 text-sm">{formatDate(submission.when)}</p>
            </div>
            {submission.where ? (
              <div>
                <h3 className="text-sm font-medium text-gray-400 mb-1">Submitted From</h3>
                <p className="text-gray-300 text-sm">{submission.where}</p>
                {/^[\-0-9.]+,[\-0-9.]+$/.test(submission.where) && (
                  <a
                    href={`https://www.google.com/maps?q=${submission.where}`}
                    target="_blank"
                    rel="noreferrer"
                    className="text-xs text-blue-400 hover:text-blue-300"
                  >
                    Open in Maps
                  </a>
                )}
              </div>
            ) : (
              <div>
                <h3 className="text-sm font-medium text-gray-400 mb-1">Submitted From</h3>
                <p className="text-gray-500 italic">GPS not available</p>
              </div>
            )}
          </div>
          {Object.keys(metadata).length > 0 && (
            <div className="bg-gray-950 border border-gray-800 rounded p-4">
              <h3 className="text-sm font-medium text-gray-400 mb-3">Submission Metadata</h3>
              <div className="grid grid-cols-2 gap-3 text-sm">
                {metadata.deviceInfo && (
                  <div>
                    <span className="text-gray-500 text-xs block">Device</span>
                    <span className="text-gray-300">{String(metadata.deviceInfo)}</span>
                  </div>
                )}
                {metadata.timezone && (
                  <div>
                    <span className="text-gray-500 text-xs block">Timezone</span>
                    <span className="text-gray-300">{String(metadata.timezone)}</span>
                  </div>
                )}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Part cards */}
      {unifiedParts.map((part) => (
        <SubmissionPartCard
          key={part.index}
          partIndex={part.index}
          partTitle={part.title}
          partPhoneNumber={part.phoneNumber}
          partLocation={part.manualLocation}
          partDate={part.date}
          media={part.media}
          mediaUrls={mediaUrls}
          isAdminView={isAdminView}
          isOriginal={part.isOriginal}
        />
      ))}

      {/* Add to this submission - user only */}
      {!isAdminView && (
        <div className="bg-gray-900 border border-gray-800 rounded-lg p-5 mb-6">
          <h3 className="text-lg font-semibold text-gray-100 mb-4">Add to this Submission</h3>

          {addError && (
            <div className="bg-red-900/50 border border-red-700 text-red-300 px-4 py-3 rounded mb-4 text-sm">
              {addError}
            </div>
          )}

          <div className="space-y-4">
            {/* Field Checkboxes */}
            <div className="bg-gray-950 border border-gray-800 rounded-lg p-4">
              <p className="text-xs text-gray-500 mb-3">Select what you want to add. A checked field is required.</p>
              <div className="grid grid-cols-3 gap-2">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={addCheckTitle}
                    onChange={() => setAddCheckTitle(!addCheckTitle)}
                    disabled={isAdding}
                    className="form-checkbox rounded border-gray-600 bg-gray-800 text-blue-600 focus:ring-blue-500 focus:ring-offset-0 w-4 h-4 disabled:opacity-40"
                  />
                  <span className={`text-sm ${addCheckTitle ? 'text-gray-200' : 'text-gray-500'}`}>Title</span>
                  {addCheckTitle && (addTitle.trim() ? <span className="text-green-400 text-xs">✓</span> : <span className="text-red-400 text-xs">●</span>)}
                </label>
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={addCheckImage}
                    onChange={() => setAddCheckImage(!addCheckImage)}
                    disabled={isAdding}
                    className="form-checkbox rounded border-gray-600 bg-gray-800 text-blue-600 focus:ring-blue-500 focus:ring-offset-0 w-4 h-4 disabled:opacity-40"
                  />
                  <span className={`text-sm ${addCheckImage ? 'text-gray-200' : 'text-gray-500'}`}>Image</span>
                  {addCheckImage && (addImageFiles.length > 0 ? <span className="text-green-400 text-xs">✓</span> : <span className="text-red-400 text-xs">●</span>)}
                </label>
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={addCheckVideo}
                    onChange={() => setAddCheckVideo(!addCheckVideo)}
                    disabled={isAdding}
                    className="form-checkbox rounded border-gray-600 bg-gray-800 text-blue-600 focus:ring-blue-500 focus:ring-offset-0 w-4 h-4 disabled:opacity-40"
                  />
                  <span className={`text-sm ${addCheckVideo ? 'text-gray-200' : 'text-gray-500'}`}>Video</span>
                  {addCheckVideo && (addVideoFiles.length > 0 ? <span className="text-green-400 text-xs">✓</span> : <span className="text-red-400 text-xs">●</span>)}
                </label>
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={addCheckPhone}
                    onChange={() => setAddCheckPhone(!addCheckPhone)}
                    disabled={isAdding}
                    className="form-checkbox rounded border-gray-600 bg-gray-800 text-blue-600 focus:ring-blue-500 focus:ring-offset-0 w-4 h-4 disabled:opacity-40"
                  />
                  <span className={`text-sm ${addCheckPhone ? 'text-gray-200' : 'text-gray-500'}`}>Phone</span>
                  {addCheckPhone && (addPhoneNumber.trim() ? <span className="text-green-400 text-xs">✓</span> : <span className="text-red-400 text-xs">●</span>)}
                </label>
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={addCheckLocation}
                    onChange={() => setAddCheckLocation(!addCheckLocation)}
                    disabled={isAdding}
                    className="form-checkbox rounded border-gray-600 bg-gray-800 text-blue-600 focus:ring-blue-500 focus:ring-offset-0 w-4 h-4 disabled:opacity-40"
                  />
                  <span className={`text-sm ${addCheckLocation ? 'text-gray-200' : 'text-gray-500'}`}>Location</span>
                  {addCheckLocation && ((addManualLocationCoords && addManualLocation.trim()) ? <span className="text-green-400 text-xs">✓</span> : <span className="text-red-400 text-xs">●</span>)}
                </label>
              </div>
            </div>

            {/* Title Input */}
            {addCheckTitle && (
              <div>
                <label className="block text-sm text-gray-400 mb-1">Title</label>
                <textarea
                  value={addTitle}
                  onChange={(e) => setAddTitle(e.target.value)}
                  placeholder="Brief description of what you're adding..."
                  disabled={isAdding}
                  rows={3}
                  className="w-full bg-gray-950 text-gray-200 border border-gray-700 rounded px-3 py-2 text-sm focus:outline-none focus:border-blue-500 placeholder-gray-600 disabled:opacity-40 resize-none"
                />
              </div>
            )}

            {/* Image Input */}
            {addCheckImage && (
              <div>
                <label className="block text-sm text-gray-400 mb-1">Image</label>
                <input
                  ref={addImageInputRef}
                  type="file"
                  multiple
                  accept="image/*"
                  onChange={handleAddFilesSelected}
                  disabled={isAdding}
                  className="hidden"
                />
                <button
                  type="button"
                  onClick={() => addImageInputRef.current?.click()}
                  disabled={isAdding}
                  className="border-2 border-dashed border-gray-700 hover:border-gray-600 rounded-lg p-6 text-center transition-colors w-full disabled:opacity-40"
                >
                  <div className="text-2xl mb-1">+</div>
                  <p className="text-gray-400 text-sm">Select Photos</p>
                </button>
                {addImageFiles.length > 0 && (
                  <div className="mt-2 space-y-2">
                    {addImageFiles.map((f, i) => (
                      <div key={i} className="bg-gray-950 border border-gray-800 rounded p-3 flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <span className="text-lg">🖼</span>
                          <div>
                            <p className="text-sm text-gray-200 truncate max-w-xs">{f.name}</p>
                            <p className="text-xs text-gray-500">{formatFileSize(f.size)}</p>
                          </div>
                        </div>
                        <button
                          onClick={() => setAddFiles(addFiles.filter(x => x !== f))}
                          disabled={isAdding}
                          className="text-gray-500 hover:text-red-400 text-sm disabled:opacity-40"
                        >
                          Remove
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* Video Input */}
            {addCheckVideo && (
              <div>
                <label className="block text-sm text-gray-400 mb-1">Video</label>
                <input
                  ref={addVideoInputRef}
                  type="file"
                  multiple
                  accept="video/*"
                  onChange={handleAddFilesSelected}
                  disabled={isAdding}
                  className="hidden"
                />
                <button
                  type="button"
                  onClick={() => addVideoInputRef.current?.click()}
                  disabled={isAdding}
                  className="border-2 border-dashed border-gray-700 hover:border-gray-600 rounded-lg p-6 text-center transition-colors w-full disabled:opacity-40"
                >
                  <div className="text-2xl mb-1">+</div>
                  <p className="text-gray-400 text-sm">Select Videos</p>
                </button>
                {addVideoFiles.length > 0 && (
                  <div className="mt-2 space-y-2">
                    {addVideoFiles.map((f, i) => (
                      <div key={i} className="bg-gray-950 border border-gray-800 rounded p-3 flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <span className="text-lg">🎬</span>
                          <div>
                            <p className="text-sm text-gray-200 truncate max-w-xs">{f.name}</p>
                            <p className="text-xs text-gray-500">{formatFileSize(f.size)}</p>
                          </div>
                        </div>
                        <button
                          onClick={() => setAddFiles(addFiles.filter(x => x !== f))}
                          disabled={isAdding}
                          className="text-gray-500 hover:text-red-400 text-sm disabled:opacity-40"
                        >
                          Remove
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* Phone Number Input */}
            {addCheckPhone && (
              <div>
                <label className="block text-sm text-gray-400 mb-1">Phone Number</label>
                <input
                  value={addPhoneNumber}
                  onChange={(e) => setAddPhoneNumber(e.target.value)}
                  placeholder="+1 234 567 8900"
                  disabled={isAdding}
                  className="w-full bg-gray-950 text-gray-200 border border-gray-700 rounded px-3 py-2 text-sm focus:outline-none focus:border-blue-500 placeholder-gray-600 disabled:opacity-40"
                />
              </div>
            )}

            {/* Location Input */}
            {addCheckLocation && (
              <div>
                <label className="block text-sm text-gray-400 mb-1">Location</label>
                <div className="relative">
                  <input
                    ref={addLocationInputRef}
                    value={addManualLocation}
                    onChange={(e) => {
                      const val = e.target.value;
                      setAddManualLocation(val);
                      setAddManualLocationCoords(null);
                      setAddShowSuggestions(false);
                      if (addLocationDebounceRef.current) clearTimeout(addLocationDebounceRef.current);
                      addLocationDebounceRef.current = window.setTimeout(() => {
                        searchLocation(val);
                      }, 800);
                    }}
                    onFocus={() => {
                      if (addLocationSuggestions.length > 0) setAddShowSuggestions(true);
                    }}
                    placeholder="Search for a place (e.g. Central Park, NYC)"
                    disabled={isAdding}
                    className="w-full bg-gray-950 text-gray-200 border border-gray-700 rounded px-3 py-2 text-sm focus:outline-none focus:border-blue-500 placeholder-gray-600 disabled:opacity-40 mb-1"
                  />
                  <MapPicker
                    coords={addManualLocationCoords}
                    onCoordsChange={(c) => {
                      setAddManualLocationCoords(c);
                    }}
                    searchSuggestions={addLocationSuggestions}
                    onSuggestionSelect={(s) => {
                      setAddManualLocation(s.name);
                      setAddManualLocationCoords({ lat: s.lat, lon: s.lon });
                      setAddLocationSuggestions([]);
                      setAddShowSuggestions(false);
                    }}
                  />
                  {addShowSuggestions && addLocationSuggestions.length > 0 && addLocationInputRef.current && (
                    createPortal(
                      <div
                          style={{
                            position: 'fixed',
                            top: addLocationInputRef.current!.getBoundingClientRect().bottom + 4,
                            left: addLocationInputRef.current!.getBoundingClientRect().left,
                            width: addLocationInputRef.current!.getBoundingClientRect().width,
                            zIndex: 99999,
                          }}
                          className="bg-gray-900 border border-gray-700 rounded shadow-lg max-h-48 overflow-y-auto"
                        >
                          {addLocationSuggestions.map((s, i) => (
                            <button
                              key={i}
                              type="button"
                              onMouseDown={() => {
                                setAddManualLocation(s.name);
                                setAddManualLocationCoords({ lat: s.lat, lon: s.lon });
                                setAddLocationSuggestions([]);
                                setAddShowSuggestions(false);
                              }}
                              className="w-full text-left px-3 py-2 text-sm text-gray-200 hover:bg-gray-800 first:rounded-t last:rounded-b"
                            >
                              {s.name}
                            </button>
                          ))}
                        </div>,
                      document.body
                    )
                  )}
                  {addLocationLoading && (
                    <div className="absolute right-3 top-2 text-xs text-gray-500">Searching...</div>
                  )}
                </div>
                {addManualLocationCoords && (
                  <p className="text-xs text-gray-500 mt-1">
                    ✓ {addManualLocationCoords.lat}, {addManualLocationCoords.lon}
                  </p>
                )}
              </div>
            )}

            {addProgress ? (
              <div className="text-center py-2">
                <div className="text-2xl animate-spin mb-1">⟳</div>
                <p className="text-gray-400 text-sm">{addProgress}</p>
              </div>
            ) : (
              <button
                onClick={handleAddToSubmission}
                disabled={!addHasAnyChecked || !addCanSubmit}
                className="w-full bg-blue-600 hover:bg-blue-500 disabled:opacity-40 disabled:cursor-not-allowed text-white px-6 py-3 rounded text-sm font-medium"
              >
                Add to Submission
              </button>
            )}
          </div>
        </div>
      )}

      {/* Threads */}
      {threads.length > 0 && (
        <div>
          <h3 className="text-lg font-semibold text-gray-100 mb-4">Follow-ups ({threads.length})</h3>
          <div className="space-y-3">
            {threads.map((t: any) => (
              <div key={t.id} className="bg-gray-900 border border-gray-800 rounded-lg p-4">
                <div className="flex items-center justify-between mb-1">
                  <span className="text-xs text-gray-500">{t.author || 'Admin'}</span>
                  <span className="text-xs text-gray-600">{formatDate(t.createdAt)}</span>
                </div>
                <p className="text-gray-200 text-sm">{t.content}</p>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// ── User Management ───────────────────────────────────────
function UsersView({ onBack }: { onBack: () => void }) {
  const [users, setUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const loadUsers = useCallback(() => {
    listUsers().then((r: any) => setUsers(r.data || [])).catch((e: Error) => setError(e.message)).finally(() => setLoading(false));
  }, []);

  useEffect(loadUsers, [loadUsers]);

  const handleToggleActive = async (id: string, currentActive: boolean) => {
    await updateUserStatus(id, !currentActive);
    loadUsers();
  };

  const handleDeleteUser = async (id: string) => {
    if (confirm('Delete this user?')) {
      await deleteUser(id);
      loadUsers();
    }
  };

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button onClick={onBack} className="text-gray-400 hover:text-gray-300 text-sm">← Back</button>
        <h2 className="text-xl font-semibold text-gray-100">Users</h2>
      </div>
      {error && <div className="bg-red-900/50 border border-red-700 text-red-300 px-4 py-3 rounded mb-4 text-sm">{error}</div>}
      {loading ? (
        <div className="text-gray-400">Loading...</div>
      ) : (
        <div className="grid gap-3">
          {users.map((u: any) => (
            <div key={u.id} className="bg-gray-900 border border-gray-800 rounded-lg p-4">
              <div className="flex items-center justify-between">
                <div>
                  <span className="text-gray-100 font-medium">{u.username}</span>
                  <span className={`ml-2 text-xs px-2 py-0.5 rounded font-medium ${u.role === 'ADMIN' ? 'bg-blue-900 text-blue-300' : 'bg-gray-800 text-gray-400'}`}>
                    {u.role}
                  </span>
                  <span className={`ml-2 text-xs px-2 py-0.5 rounded font-medium ${u.active ? 'bg-green-900 text-green-300' : 'bg-red-900 text-red-300'}`}>
                    {u.active ? 'Active' : 'Disabled'}
                  </span>
                  <span className="ml-2 text-xs text-gray-500">{u.submissionCount || 0} submissions</span>
                </div>
                <div className="flex gap-2">
                  <button onClick={() => handleToggleActive(u.id, u.active)} className="text-xs text-gray-400 hover:text-gray-300 px-2 py-1 border border-gray-700 rounded">
                    {u.active ? 'Disable' : 'Enable'}
                  </button>
                  <button onClick={() => handleDeleteUser(u.id)} className="text-xs text-gray-600 hover:text-red-400 px-2 py-1 border border-gray-700 rounded">
                    Delete
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ── Admin Portal ──────────────────────────────────────────
function AdminPortal({ username }: { username: string }) {
  type View =
    | { type: 'submissions' }
    | { type: 'submission'; id: string }
    | { type: 'users' }
    | { type: 'search'; query: string };

  const [view, setView] = useState<View>({ type: 'submissions' });
  const [submissions, setSubmissions] = useState<Submission[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [searchQuery, setSearchQuery] = useState('');

  // Load all submissions from all trails
  const loadSubmissions = useCallback(() => {
    setLoading(true);
    setError('');
    // Load trails, then get submissions from "evidence" trail + all others
    listTrails().then((trailsR: any) => {
      const trails = trailsR.data || [];
      return Promise.all(trails.map((t: Trail) =>
        listSubmissions(t.slug).then((r: any) => (r.data || []).map((s: Submission) => ({ ...s, trailSlug: t.slug, trailName: t.name })))
      ));
    }).then((allSubmissionsArrays) => {
      const all = allSubmissionsArrays.flat().sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
      setSubmissions(all);
    }).catch((e: Error) => setError(e.message)).finally(() => setLoading(false));
  }, []);

  useEffect(loadSubmissions, [loadSubmissions]);

  const handleSearch = async (q: string) => {
    const r = await search(q);
    const results = (r as any).data || [];
    setSubmissions(results);
    setView({ type: 'search', query: q });
  };

  return (
    <div className="min-h-screen bg-gray-950 text-gray-100">
      {/* Header */}
      <header className="border-b border-gray-800 bg-gray-950 px-6 py-4">
        <div className="max-w-6xl mx-auto flex items-center justify-between gap-4">
          <div className="flex items-center gap-4">
            <button onClick={() => setView({ type: 'submissions' })} className="text-lg font-bold text-gray-100 hover:text-white shrink-0">
              Data Collection Platform
            </button>
            <span className="bg-blue-600 text-white text-xs px-2 py-0.5 rounded font-medium">Admin</span>
          </div>
          <form onSubmit={(e) => { e.preventDefault(); if (searchQuery.trim()) handleSearch(searchQuery.trim()); }} className="flex-1 max-w-md">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search..."
              className="w-full bg-gray-900 text-gray-200 border border-gray-700 rounded px-3 py-1.5 text-sm focus:outline-none focus:border-blue-500 placeholder-gray-600"
            />
          </form>
          <div className="flex items-center gap-3 shrink-0">
            <span className="text-sm text-gray-400">{username}</span>
            <button onClick={() => { logout(); window.location.reload(); }} className="text-sm text-gray-400 hover:text-gray-300">
              Logout
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-6 py-8">
        {/* Nav */}
        {view.type === 'submissions' && (
          <div className="flex gap-3 mb-6">
            <button onClick={() => setView({ type: 'submissions' })} className="text-sm text-gray-400 hover:text-gray-300 px-3 py-1.5 bg-gray-900 border border-gray-800 rounded">
              All Submissions ({submissions.length})
            </button>
            <button onClick={() => setView({ type: 'users' })} className="text-sm text-gray-400 hover:text-gray-300 px-3 py-1.5 bg-gray-900 border border-gray-800 rounded">
              Users
            </button>
          </div>
        )}

        {error && (
          <div className="bg-red-900/50 border border-red-700 text-red-300 px-4 py-3 rounded mb-4 text-sm">
            Error: {error}
          </div>
        )}

        {loading && <div className="text-gray-400 mb-4">Loading...</div>}

        {view.type === 'submissions' && !loading && (
          <div>
            <h2 className="text-xl font-semibold text-gray-100 mb-6">All Submissions</h2>
            {submissions.length === 0 ? (
              <div className="text-gray-500">No submissions yet.</div>
            ) : (
              <div className="grid gap-3">
                {submissions.map((s) => {
                  const titleText = s.what?.trim()
                    ? s.what.length > 200 ? s.what.slice(0, 200) + '...' : s.what
                    : '[No title]';
                  return (
                  <div key={s.id} className="bg-gray-900 border border-gray-800 rounded-lg p-4 hover:border-gray-700 transition-colors">
                    <button
                      onClick={() => setView({ type: 'submission', id: s.id })}
                      className={`text-sm text-left w-full ${!s.what?.trim() ? 'text-gray-500' : 'text-blue-400 hover:text-blue-300'}`}
                    >
                      {titleText}
                    </button>
                    <div className="flex items-center gap-3 mt-2 text-xs text-gray-500">
                      <span>📍 {s.where || 'Unknown'}</span>
                      <span>🕐 {formatDate(s.when)}</span>
                      <span>Trail: {s.trailSlug || s.trailName}</span>
                      {s.submittedBy && <span>by {s.submittedBy}</span>}
                      <span>{s.mediaCount || 0} files</span>
                      <span>{s.threadCount || 0} follow-ups</span>
                    </div>
                  </div>
                );
                })}
              </div>
            )}
          </div>
        )}

        {view.type === 'submission' && (
          <SubmissionDetailView
            id={view.id}
            onBack={() => setView({ type: 'submissions' })}
            isAdminView
          />
        )}

        {view.type === 'users' && (
          <UsersView onBack={() => setView({ type: 'submissions' })} />
        )}

        {view.type === 'search' && (
          <div>
            <div className="flex items-center gap-4 mb-6">
              <button onClick={() => setView({ type: 'submissions' })} className="text-gray-400 hover:text-gray-300 text-sm">← Back</button>
              <h2 className="text-xl font-semibold text-gray-100">Search: "{view.query}"</h2>
            </div>
            <div className="grid gap-3">
              {submissions.map((s) => (
                <div key={s.id} className="bg-gray-900 border border-gray-800 rounded-lg p-4">
                  <button
                    onClick={() => setView({ type: 'submission', id: s.id })}
                    className="text-blue-400 hover:text-blue-300 text-sm text-left w-full"
                  >
                    {s.what?.length > 200 ? s.what.slice(0, 200) + '...' : s.what}
                  </button>
                  <div className="flex items-center gap-3 mt-2 text-xs text-gray-500">
                    <span>📍 {s.where || s.where_field}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </main>
    </div>
  );
}

// ── Main App ──────────────────────────────────────────────
export default function App() {
  const [page, setPage] = useState<'public' | 'login' | 'admin'>('public');
  const user = getCurrentUser();

  useEffect(() => {
    if (user && isAdmin()) {
      setPage('admin');
    } else if (user) {
      setPage('public');
    }
  }, [user]);

  if (page === 'admin') {
    return <AdminPortal username={user!.username} />;
  }

  if (page === 'login') {
    return <LoginPage onSuccess={() => window.location.reload()} onBack={() => setPage('public')} />;
  }

  return <PublicEvidencePortal onAdminLogin={() => setPage('login')} />;
}
