/**
 * Sameko Dev C++ IDE - Snippets Manager
 * Code snippet management and insertion
 * 
 * @module src/features/snippets/snippets-manager
 */

// ============================================================================
// DEFAULT SNIPPETS
// ============================================================================

const BUILTIN_SNIPPETS = [
    {
        trigger: 'cp',
        name: 'CP Template',
        content: `#include <bits/stdc++.h>
using namespace std;

void solve() {
    \${1:// solution here}
}

int main() {
    ios_base::sync_with_stdio(false);
    cin.tie(NULL);
    
    int t = 1;
    \${2:cin >> t;}
    while (t--) {
        solve();
    }
    
    return 0;
}`,
        isBuiltin: true
    },
    {
        trigger: 'main',
        name: 'Main Function',
        content: `int main() {
    ios_base::sync_with_stdio(false);
    cin.tie(NULL);
    
    \${1:// code}
    
    return 0;
}`,
        isBuiltin: true
    },
    {
        trigger: 'fastio',
        name: 'Fast I/O',
        content: `ios_base::sync_with_stdio(false);\ncin.tie(NULL);`,
        isBuiltin: true
    },
    {
        trigger: 'for',
        name: 'For Loop',
        content: 'for (int \${1:i} = 0; \${1:i} < \${2:n}; \${1:i}++) {\n    \${3:// body}\n}',
        isBuiltin: true
    },
    {
        trigger: 'fori',
        name: 'For Loop (iterator)',
        content: 'for (auto \${1:it} = \${2:v}.begin(); \${1:it} != \${2:v}.end(); ++\${1:it}) {\n    \${3:// body}\n}',
        isBuiltin: true
    },
    {
        trigger: 'fore',
        name: 'Range-based For',
        content: 'for (auto& \${1:x} : \${2:container}) {\n    \${3:// body}\n}',
        isBuiltin: true
    },
    {
        trigger: 'cin',
        name: 'Compact Read',
        content: 'cin >> \${1:n};',
        isBuiltin: true
    },
    {
        trigger: 'cout',
        name: 'Print Line',
        content: 'cout << \${1:x} << "\\n";',
        isBuiltin: true
    },
    {
        trigger: 'vector',
        name: 'STL Vector',
        content: 'vector<\${1:int}> \${2:v};',
        isBuiltin: true
    },
    {
        trigger: 'map',
        name: 'STL Map',
        content: 'map<\${1:int}, \${2:int}> \${3:m};',
        isBuiltin: true
    },
    {
        trigger: 'set',
        name: 'STL Set',
        content: 'set<\${1:int}> \${2:s};',
        isBuiltin: true
    },
    {
        trigger: 'pq',
        name: 'Priority Queue',
        content: 'priority_queue<\${1:int}> \${2:pq};',
        isBuiltin: true
    },
    {
        trigger: 'pbds',
        name: 'PBDS (Ordered Set)',
        content: `#include <ext/pb_ds/assoc_container.hpp>
#include <ext/pb_ds/tree_policy.hpp>
using namespace __gnu_pbds;
template <typename T>
using ordered_set = tree<T, null_type, less<T>, rb_tree_tag, tree_order_statistics_node_update>;`,
        isBuiltin: true
    },
    {
        trigger: 'gcd',
        name: 'Greatest Common Divisor',
        content: `long long gcd(long long a, long long b) {\n    return b == 0 ? a : gcd(b, a % b);\n}`,
        isBuiltin: true
    },
    {
        trigger: 'lcm',
        name: 'Least Common Multiple',
        content: `long long lcm(long long a, long long b) {\n    return (a / gcd(a, b)) * b;\n}`,
        isBuiltin: true
    },
    {
        trigger: 'binpow',
        name: 'Binary Exponentiation',
        content: `long long binpow(long long a, long long b, long long m) {\n    a %= m;\n    long long res = 1;\n    while (b > 0) {\n        if (b & 1) res = res * a % m;\n        a = a * a % m;\n        b >>= 1;\n    }\n    return res;\n}`,
        isBuiltin: true
    },
    {
        trigger: 'dsu',
        name: 'Disjoint Set Union (DSU)',
        content: `struct DSU {\n    vector<int> parent;\n    DSU(int n) {\n        parent.resize(n + 1);\n        iota(parent.begin(), parent.end(), 0);\n    }\n    int find(int i) {\n        if (parent[i] == i) return i;\n        return parent[i] = find(parent[i]);\n    }\n    void unite(int i, int j) {\n        int root_i = find(i);\n        int root_j = find(j);\n        if (root_i != root_j) parent[root_i] = root_j;\n    }\n};`,
        isBuiltin: true
    }
];

// ============================================================================
// SNIPPETS STATE
// ============================================================================

let customSnippets = [];

// ============================================================================
// SNIPPETS FUNCTIONS
// ============================================================================

/**
 * Get all snippets
 * @returns {Array}
 */
function getAllSnippets() {
    return [...BUILTIN_SNIPPETS, ...customSnippets];
}

/**
 * Get snippet by trigger
 * @param {string} trigger
 * @returns {Object|undefined}
 */
function getSnippet(trigger) {
    return getAllSnippets().find(s => s.trigger === trigger);
}

/**
 * Add custom snippet
 * @param {Object} snippet
 */
function addSnippet(snippet) {
    customSnippets.push({
        ...snippet,
        isBuiltin: false
    });
    saveCustomSnippets();
}

/**
 * Remove custom snippet
 * @param {string} trigger
 */
function removeSnippet(trigger) {
    customSnippets = customSnippets.filter(s => s.trigger !== trigger);
    saveCustomSnippets();
}

/**
 * Load custom snippets from settings
 */
function loadCustomSnippets() {
    const settings = window.SettingsManager?.getSettings?.();
    if (settings?.snippets) {
        customSnippets = settings.snippets.filter(s => !s.isBuiltin);
    }
}

/**
 * Save custom snippets to settings
 */
function saveCustomSnippets() {
    window.SettingsManager?.updateSetting?.('snippets', getAllSnippets());
}

/**
 * Register Monaco snippet completions
 * @param {monaco} monaco
 */
function registerMonacoCompletions(monaco) {
    monaco.languages.registerCompletionItemProvider('cpp', {
        provideCompletionItems: (model, position) => {
            const snippets = getAllSnippets();
            return {
                suggestions: snippets.map(s => ({
                    label: s.trigger,
                    kind: monaco.languages.CompletionItemKind.Snippet,
                    insertText: s.content,
                    insertTextRules: monaco.languages.CompletionItemInsertTextRule.InsertAsSnippet,
                    detail: s.name,
                    documentation: s.content
                }))
            };
        }
    });
}

// ============================================================================
// EXPORTS
// ============================================================================

if (typeof module !== 'undefined' && module.exports) {
    module.exports = { BUILTIN_SNIPPETS, getAllSnippets, getSnippet, addSnippet, removeSnippet, loadCustomSnippets, registerMonacoCompletions };
}

if (typeof window !== 'undefined') {
    window.SnippetsManager = { BUILTIN_SNIPPETS, getAllSnippets, getSnippet, addSnippet, removeSnippet, loadCustomSnippets, registerMonacoCompletions };
}
