// SPDX-License-Identifier: MIT
.pragma library

// Value axes for the charts, with round steps (1, 2 or 5 times a power of
// ten) so the labels read well. An axis is {from, to, step, intervals}; each
// helper tries a few interval counts and keeps the tightest axis.

function niceStep(raw) {
    if (!(raw > 0) || !isFinite(raw)) {
        return 1;
    }
    const magnitude = Math.pow(10, Math.floor(Math.log10(raw)));
    const residual = raw / magnitude;
    for (const nice of [1, 2, 5]) {
        if (residual <= nice + 1e-9) {
            return nice * magnitude;
        }
    }
    return 10 * magnitude;
}

function tightest(candidates) {
    let best = null;
    for (const axis of candidates) {
        if (!best || axis.to - axis.from < best.to - best.from - 1e-9) {
            best = axis;
        }
    }
    return best;
}

// From zero up to a round value at or above `max` (bar charts).
function zeroBased(max, minIntervals, maxIntervals) {
    const candidates = [];
    for (let intervals = minIntervals; intervals <= maxIntervals; ++intervals) {
        const step = niceStep(max / intervals);
        candidates.push({ from: 0, to: step * intervals, step: step, intervals: intervals });
    }
    return tightest(candidates);
}

// Round ends around [min, max] (line charts). A flat series gets some room
// above and below instead of an axis with the same value at both ends.
function around(min, max, minIntervals, maxIntervals) {
    let low = min;
    let high = max;
    if (!(high > low)) {
        const pad = Math.max(Math.abs(high) * 0.01, 1);
        low -= pad;
        high += pad;
    }
    const candidates = [];
    for (let intervals = minIntervals; intervals <= maxIntervals; ++intervals) {
        let step = niceStep((high - low) / intervals);
        for (let i = 0; i < 20; ++i) {
            const from = Math.floor(low / step) * step;
            if (from + step * intervals >= high) {
                candidates.push({ from: from, to: from + step * intervals, step: step, intervals: intervals });
                break;
            }
            step = niceStep(step * 1.01);
        }
    }
    return tightest(candidates) || { from: low, to: high, step: (high - low) / minIntervals, intervals: minIntervals };
}
