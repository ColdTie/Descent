export const RESOURCE_IDS = ['ore', 'metal', 'volatiles', 'fuel', 'parts', 'power'] as const;
export type ResourceId = (typeof RESOURCE_IDS)[number];

export const RESOURCE_NAMES: Record<ResourceId, string> = {
  ore: 'Ore',
  metal: 'Metal',
  volatiles: 'Volatiles',
  fuel: 'Fuel',
  parts: 'Parts',
  power: 'Power',
};

/** What a freshly launched Vessel carries. */
export const STARTING_STOCK: Record<ResourceId, number> = {
  ore: 0,
  metal: 0,
  volatiles: 0,
  fuel: 100,
  parts: 20,
  power: 0,
};
