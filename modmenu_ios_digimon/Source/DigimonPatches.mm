// ============================================================================
// Digimon iOS - liga/desliga do DANO por FLAG (ver DigimonPatches.h)
// ============================================================================

#import "DigimonPatches.h"
#import "../utils/libtitanox/libtitanox/libtitanox.h"
#import "../utils/libtitanox/utils/utils.h"   // THLog (funcao C, varargs corretos)

// LOG: usar SEMPRE a funcao C THLog(...), NUNCA [TitanoxHook log:...] (o wrapper
// do template repassa um va_list e crasha com %s/%@).
#define DGLOG(...) THLog(__VA_ARGS__)

static uint64_t          g_base = 0;
static volatile uint8_t *g_flag = NULL;   // aponta pro slack gravavel do __DATA
static BOOL              g_ok   = NO;
static NSString         *g_erro = nil;

@implementation DigimonPatches

+ (void)inicializar {
    g_base = [TitanoxHook getBaseAddressOfLibrary:DG_IMAGE_NAME];
    DGLOG(@"[DG] base de %s = 0x%llx", DG_IMAGE_NAME, (unsigned long long)g_base);

    if (g_base == 0) {
        g_erro = @"UnityFramework nao encontrado no processo";
        DGLOG(@"[DG] ERRO: %@", g_erro);
        return;
    }

    // A flag mora no slack gravavel do __DATA (rw-, demand-zero). Acesso direto:
    // e memoria do nosso proprio processo, NAO passa por mach_vm_read/protect
    // (que disparam EXC_GUARD no iOS 26). Nao e pagina de codigo -> escrever ali
    // e permitido e nao dispara o code signing monitor.
    g_flag = (volatile uint8_t *)(uintptr_t)(g_base + DG_FLAG_RVA);

    uint8_t v = *g_flag;   // leitura de teste
    g_ok = YES;
    DGLOG(@"[DG] flag @0x%llx = %u (0 = dano LIGADO)",
          (unsigned long long)(uintptr_t)g_flag, (unsigned)v);
}

+ (BOOL)valido { return g_ok; }

+ (BOOL)danoLigado { return (g_ok && *g_flag == 0) ? YES : NO; }

+ (BOOL)definirDano:(BOOL)ligar {
    if (!g_ok) {
        DGLOG(@"[DG] definirDano ignorado (flag inacessivel)");
        return NO;
    }
    uint8_t alvo = ligar ? 0 : 1;
    *g_flag = alvo;
    __sync_synchronize();          // garante a escrita visivel antes da releitura
    BOOL ok = (*g_flag == alvo);
    DGLOG(@"[DG] definirDano ligar=%d -> flag=%u %s",
          (int)ligar, (unsigned)*g_flag, ok ? "OK" : "FALHOU");
    if (!ok) g_erro = @"escrita da flag nao confirmada";
    return ok;
}

+ (NSString *)diagnostico {
    if (!g_ok) {
        return [NSString stringWithFormat:@"base 0x%llx | flag inacessivel%@",
                (unsigned long long)g_base,
                g_erro ? [@" | " stringByAppendingString:g_erro] : @""];
    }
    return [NSString stringWithFormat:@"base 0x%llx | flag=%u | dano %@",
            (unsigned long long)g_base, (unsigned)*g_flag,
            (*g_flag == 0) ? @"LIGADO" : @"desligado"];
}

@end
