import { PrismaClient } from '@prisma/client';

export interface GeoJSONPoint {
  type: 'Point';
  coordinates: [number, number]; // [lng, lat]
}

export interface GeoJSONPolygon {
  type: 'Polygon';
  coordinates: [number, number][][];
}

/**
 * Convert GeoJSON Point to WKB bytes for PostGIS storage.
 */
export async function geojsonToWkb(prisma: PrismaClient, geojson: GeoJSONPoint | GeoJSONPolygon): Promise<Buffer> {
  const result = await prisma.$queryRaw<
    { wkb: Buffer }[]
  >`SELECT ST_AsBinary(ST_GeomFromGeoJSON(${JSON.stringify(geojson)}::json)) AS wkb`;
  return result[0].wkb;
}

/**
 * Convert WKB bytes from PostGIS back to GeoJSON.
 */
export async function wkbToGeojson(prisma: PrismaClient, wkb: Buffer): Promise<GeoJSONPoint | GeoJSONPolygon | null> {
  if (!wkb) return null;
  const result = await prisma.$queryRaw<
    { geojson: string }[]
  >`SELECT ST_AsGeoJSON(ST_GeomFromWKB($1)) AS geojson`, wkb;
  return JSON.parse(result[0].geojson);
}
