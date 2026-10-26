import NeNeWireCore

/// 翻訳の手段（Argos Translate）の呼び方（ADR 0010）。翻訳の手段を差し替えるときは、この型と `TranslationReply` の形を替える（FR-28）。
///
/// `python3 -c <小さな台本> <元の言語> <訳す言語> <文字列…>` を子プロセスで走らせ、1 行 1 件で `<番号>\t<訳>` を受け取る。
/// Argos は `install-translator.sh` が入れた置き場（`PYTHONPATH`）から読み込む。文の区切りは MINISBD（Argos の公式の設定）にし、
/// torch を連れてくる stanza は使わない。Argos が最初に `import stanza` するので、その名前だけ空のモジュールで満たす。
public enum TranslateCommand {
    /// 実行ファイルの名前（`PATH` から探す）。
    public static let executable = "python3"

    static let script = """
        import sys, types
        sys.modules.setdefault('stanza', types.ModuleType('stanza'))
        try:
            import argostranslate.translate as t
        except Exception:
            print('ERR\\timport', flush=True)
            sys.exit(3)
        source, target = sys.argv[1], sys.argv[2]
        languages = {language.code: language for language in t.get_installed_languages()}
        pair = languages[source].get_translation(languages[target]) if source in languages and target in languages else None
        if pair is None:
            print('ERR\\tmodel', flush=True)
            sys.exit(4)
        for index, text in enumerate(sys.argv[3:]):
            out = ' '.join(pair.translate(text).split())
            print(str(index) + '\\t' + out, flush=True)
        """

    /// 文字列を訳す子プロセス。`library` は Argos の置き場、`environment` は呼ぶ側が読んだ環境変数（`HOME` などを含める）。
    /// `route` は元の言語と訳す言語のコード。
    public static func command(
        texts: [String], route: (source: String, target: String), library: String, environment: [String]
    ) -> ChildCommand {
        let settings = ["PYTHONPATH=\(library)", "ARGOS_CHUNK_TYPE=MINISBD", "PYTHONIOENCODING=utf-8"]
        return ChildCommand(
            executable: executable, arguments: ["-c", script, route.source, route.target] + texts,
            environment: environment.filter { !$0.hasPrefix("PYTHONPATH=") } + settings)
    }
}
