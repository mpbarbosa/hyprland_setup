pragma Singleton
import Quickshell

// Ranking for the picker's filter, so "tn" finds tokyo-night and "rp" finds rose-pine.
//
// fuzzysort is the usual answer to this and is 682 lines. For fifteen short hyphenated
// names that is more dependency than the problem deserves, and a scorer that knows the
// names are kebab-case ranks them better than a general-purpose one: the hyphen is a word
// boundary, and initials across boundaries are how people actually abbreviate these.
//
// Swap in fuzzysort if the list ever grows into the hundreds, where its indexing wins.
Singleton {
    id: root

    // -1 means the query is not even a subsequence of the candidate. Higher is better.
    function score(candidate, query) {
        if (query === "")
            return 0;

        var c = candidate.toLowerCase();
        var q = query.toLowerCase();

        var total = 0;
        var from = 0;      // next index in the candidate still available to match
        var streak = 0;

        for (var qi = 0; qi < q.length; qi++) {
            var at = c.indexOf(q.charAt(qi), from);
            if (at === -1)
                return -1;

            var points = 1;
            if (at === 0)
                points += 8;                       // the very start of the name
            else if (c.charAt(at - 1) === "-")
                points += 6;                       // the start of a word within it

            if (at === from && qi > 0) {
                streak++;
                points += 2 + streak;              // adjacent runs beat scattered letters
            } else {
                streak = 0;
            }

            total += points;
            from = at + 1;
        }

        // Shorter names win ties, so "n" prefers nord over tokyo-night.
        return total * 100 - c.length;
    }

    // Filters and reorders in one pass. `key` names the property to match on; ties keep
    // the original order, which keeps the list from reshuffling under a broad query.
    function filter(items, query, key) {
        if (query === "")
            return items;

        var scored = [];
        for (var i = 0; i < items.length; i++) {
            var s = root.score(String(items[i][key]), query);
            if (s >= 0)
                scored.push({ item: items[i], score: s, order: i });
        }
        scored.sort(function (a, b) {
            return b.score - a.score || a.order - b.order;
        });
        return scored.map(function (e) { return e.item; });
    }
}
