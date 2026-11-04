export function Footnote({ children }: { children: string }) {
  return (
    <footer className="mx-auto max-w-2xl border-t border-line px-6 py-8 text-center text-[15px] text-dust">
      {children}
    </footer>
  )
}
