import Glibc

/// 文字列のファイルの読み書き（設定の保存・ADR 0011）。ファイルに触れる経路はここ 1 か所。
/// 書くときは同じディレクトリの一時ファイルに書いてから名前を替える（途中で落ちても、元のファイルか新しいファイルのどちらかが残る）。
public enum TextFile {
    public static func read(_ path: String) -> FileRead {
        let fd = open(path, O_RDONLY | O_CLOEXEC)
        guard fd >= 0 else {
            return errno == ENOENT ? .missing : .failed(errno)
        }
        defer { close(fd) }
        var bytes: [UInt8] = []
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while true {
            let count = buffer.withUnsafeMutableBytes { Glibc.read(fd, $0.baseAddress, $0.count) }
            if count == 0 {
                return .text(String(decoding: bytes, as: UTF8.self))
            }
            if count < 0 {
                if errno == EINTR {
                    continue
                }
                return .failed(errno)
            }
            bytes += buffer.prefix(count)
        }
    }

    /// 書く。親のディレクトリが無ければ作る。
    public static func write(_ path: String, text: String) -> FileWrite {
        guard makeParents(of: path) else {
            return .failed(errno)
        }
        let temporary = path + ".tmp"
        let fd = open(temporary, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0o644)
        guard fd >= 0 else {
            return .failed(errno)
        }
        let bytes = Array(text.utf8)
        var offset = 0
        while offset < bytes.count {
            let written = bytes[offset...].withUnsafeBytes { Glibc.write(fd, $0.baseAddress, $0.count) }
            if written < 0, errno == EINTR {
                continue
            }
            guard written > 0 else {
                let code = errno
                close(fd)
                unlink(temporary)
                return .failed(code)
            }
            offset += written
        }
        guard fsync(fd) == 0, close(fd) == 0, rename(temporary, path) == 0 else {
            let code = errno
            unlink(temporary)
            return .failed(code)
        }
        return .written
    }

    /// 親のディレクトリを上から順に作る（あればそのまま）。
    private static func makeParents(of path: String) -> Bool {
        let parts = path.split(separator: "/").dropLast()
        var current = path.hasPrefix("/") ? "" : "."
        for part in parts {
            current += "/" + part
            if mkdir(current, 0o755) != 0, errno != EEXIST {
                return false
            }
        }
        return true
    }
}
