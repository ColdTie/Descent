import { CRUISE_SPEED_C } from './stars';

/** Acceleration in c per game year: cruise is reached after one year of burn, covering 0.1 ly. */
export const ACCEL_C_PER_YEAR = 0.2;
/** Fuel per game year of burn, for the launch burn and the deceleration burn alike. */
export const BURN_FUEL_PER_YEAR = 30;
/** Hull damage per game year of deceleration burned without fuel (a full dry braking costs 60). */
export const DRY_DECEL_HULL_PER_YEAR = 60;
/** Speed floor while decelerating, so a Vessel always creeps the last stretch. */
export const MIN_SPEED_C = 0.002;
export { CRUISE_SPEED_C };

/** System couplings: a weak drive burns fuel twice as fast; a dead reactor doubles wear elsewhere; weak sensors see debris late. */
export const WEAK_DRIVE_BELOW = 25;
export const WEAK_DRIVE_FUEL_MULT = 2;
export const POWER_OUT_WEAR_MULT = 2;
export const WEAK_SENSORS_BELOW = 25;
export const WEAK_SENSORS_DAMAGE_MULT = 1.5;

/** Repairs through the Fabricator: Parts per repair and integrity restored at a healthy Fabricator. */
export const REPAIR_PARTS = 2;
export const REPAIR_AMOUNT = 10;
