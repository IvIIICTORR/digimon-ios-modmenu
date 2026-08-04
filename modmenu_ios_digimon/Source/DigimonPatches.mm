// ============================================================================
// Digimon iOS - implementacao do liga/desliga (ver DigimonPatches.h)
// ============================================================================

#import "DigimonPatches.h"
#import "../utils/libtitanox/libtitanox/libtitanox.h"
#import "../utils/libtitanox/utils/utils.h"   // THLog (funcao C, varargs corretos)

#include <mach/mach.h>
#include <mach/vm_map.h>
#include <libkern/OSCacheControl.h>   // sys_icache_invalidate
#include <string.h>

// ---------------------------------------------------------------------------
// LOG: usar SEMPRE a funcao C THLog(...), NUNCA [TitanoxHook log:...].
//
// O wrapper +[TitanoxHook log:] do template repassa um va_list como se fosse o
// primeiro argumento variadico de THLog (bug de encaminhamento de varargs).
// Com qualquer especificador que dereferencia ponteiro (%s, %@) ele le um
// ponteiro invalido e da SIGSEGV. A funcao C THLog trata os varargs certo.
// Este era o motivo de o jogo fechar ao abrir o menu.
// ---------------------------------------------------------------------------
#define DGLOG(...) THLog(__VA_ARGS__)

// ---------------------------------------------------------------------------
// Acesso a memoria SEM o TotallyNotVM do Titanox.
//
// O TotallyNotVM::read/protect/write montam a mensagem MIG do mach_vm_* na mao
// e chamam mach_msg com um reply port de mig_get_reply_port(). No iOS 26 isso
// dispara EXC_GUARD (GUARD_TYPE_MACH_PORT / INVALID_OPTIONS) e mata o processo
// - foi exatamente o crash observado ao abrir o menu (crash log: Thread 0 em
// TotallyNotVM::read -> mach_msg). Como estamos no NOSSO processo, usamos as
// APIs padrao: leitura por memcpy (paginas de codigo sao R-X, logo legiveis) e
// escrita via vm_protect (funcao do sistema, nao dispara o guard) + memcpy.
// ---------------------------------------------------------------------------
static bool dgRead(uint64_t addr, void *buf, size_t n) {
    if (addr == 0) return false;
    memcpy(buf, (const void *)(uintptr_t)addr, n);   // R-X e legivel
    return true;
}

static kern_return_t dgProtect(uint64_t addr, size_t n, vm_prot_t prot) {
    mach_vm_address_t pg  = (mach_vm_address_t)addr & ~((mach_vm_address_t)vm_page_size - 1);
    mach_vm_size_t    len = ((mach_vm_address_t)addr + n) - pg;
    return vm_protect(mach_task_self(), (vm_address_t)pg, (vm_size_t)len, FALSE, prot);
}

static bool dgWrite(uint64_t addr, const void *data, size_t n) {
    // 1) tornar a pagina gravavel. VM_PROT_COPY forca copia privada (COW),
    //    necessario para pagina de codigo assinada.
    kern_return_t kr = dgProtect(addr, n, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        kr = dgProtect(addr, n, VM_PROT_READ | VM_PROT_WRITE);
    }
    if (kr != KERN_SUCCESS) {
        DGLOG(@"[DG] vm_protect(RW) falhou kr=%d em 0x%llx", kr, (unsigned long long)addr);
        return false;
    }
    // 2) escrever
    memcpy((void *)(uintptr_t)addr, data, n);
    // 3) devolver R-X e invalidar o cache de instrucoes
    dgProtect(addr, n, VM_PROT_READ | VM_PROT_EXECUTE);
    sys_icache_invalidate((void *)(uintptr_t)addr, n);
    return true;
}

// ---------------------------------------------------------------------------
// Tabela de alvos.
//
// Cada entrada guarda RVA, os bytes do STUB (cheat ligado) e os bytes ORIGINAIS
// (cheat desligado). Os originais foram capturados pelo patcher no momento em
// que gravou o IPA - estao no OFFSETS_DIGIMON_IOS.md e no log do patch.
//
// NOTA sobre RVA: no UnityFramework deste jogo o segmento __TEXT tem vmaddr=0,
// entao RVA == offset de arquivo == deslocamento a partir da base carregada.
// A funcao inicializar() confirma isso comparando os bytes.
// ---------------------------------------------------------------------------
typedef struct {
    uint64_t rva;
    const char *nome;
    uint8_t stub[48];       // cheat LIGADO
    uint8_t original[48];   // cheat DESLIGADO
    size_t  tam;
} DgAlvo;

static DgAlvo g_alvos[DG_TOTAL] = {

    // --- GetTypeDamage: aliado x1000 / inimigo 0 (dano + modo deus) ---
    {
        0x3127250, "Dano x1000 + Modo Deus",
        {0x41,0x01,0x00,0xB4, 0x28,0x30,0x40,0xB9, 0x1F,0x19,0x00,0x71,
         0xA2,0x00,0x00,0x54, 0x09,0x7D,0x80,0x52, 0x21,0x01,0x62,0x1E,
         0x00,0x08,0x61,0x1E, 0xC0,0x03,0x5F,0xD6, 0xE0,0x03,0x67,0x9E,
         0xC0,0x03,0x5F,0xD6, 0xC0,0x03,0x5F,0xD6},
        {0xED,0x33,0xBA,0x6D, 0xEB,0x2B,0x01,0x6D, 0xE9,0x23,0x02,0x6D,
         0xF6,0x57,0x03,0xA9, 0xF4,0x4F,0x04,0xA9, 0xFD,0x7B,0x05,0xA9,
         0xFD,0x43,0x01,0x91, 0xF3,0x03,0x02,0xAA, 0x08,0x1C,0xA0,0x4E,
         0xF4,0x03,0x01,0xAA, 0xF5,0x03,0x00,0xAA},
        44
    },

    // --- GetAttackTime -> 0.1s ---
    {
        0x2CDCCDC, "Cadencia de Ataque (0.1s)",
        {0x88,0x0C,0x80,0x52, 0x00,0x01,0x22,0x1E, 0x09,0x7D,0x80,0x52,
         0x21,0x01,0x22,0x1E, 0x00,0x18,0x21,0x1E, 0xC0,0x03,0x5F,0xD6},
        {0xE9,0x23,0xBE,0x6D, 0xFD,0x7B,0x01,0xA9, 0xFD,0x43,0x00,0x91,
         0x00,0x14,0x40,0xF9, 0x20,0x02,0x00,0xB4, 0x61,0x00,0x80,0x52},
        24
    },

    // --- CheckDamageEvade -> false ---
    {
        0x313B66C, "Nunca Errar",
        {0x00,0x00,0x80,0x52, 0xC0,0x03,0x5F,0xD6},
        {0xFF,0x83,0x01,0xD1, 0xE9,0x23,0x03,0x6D},
        8
    },

    // --- SetGameSpeed: constante do estado X1 (1.0 -> 5.0) ---
    {
        0x32AE148, "Velocidade 5x (estado X1)",
        {0x01,0x90,0x22,0x1E},
        {0x01,0x10,0x2E,0x1E},
        4
    },

    // --- SetGameSpeed: constante do estado X2 (2.0 -> 5.0) ---
    {
        0x32AE150, "Velocidade 5x (estado X2)",
        {0x02,0x90,0x22,0x1E},
        {0x02,0x10,0x20,0x1E},
        4
    },

    // --- PS_ADView b__0 -> b__3(0): recompensa sem video ---
    {
        0x2E5D7E4, "Pular Video de Anuncio",
        {0x01,0x00,0x80,0x52, 0xB7,0x00,0x00,0x14},
        {0xF8,0x5F,0xBC,0xA9, 0xF6,0x57,0x01,0xA9},
        8
    },
};

static uint64_t g_base = 0;
static BOOL g_ligada[DG_TOTAL] = {NO};
static BOOL g_valida[DG_TOTAL] = {NO};
static BOOL g_escritaOk = NO;
static BOOL g_iniciado  = NO;
static NSString *g_erro = nil;

@implementation DigimonPatches

+ (const char *)nome:(DgFeature)f {
    if (f < 0 || f >= DG_TOTAL) return "?";
    return g_alvos[f].nome;
}

+ (BOOL)estaLigada:(DgFeature)f {
    if (f < 0 || f >= DG_TOTAL) return NO;
    return g_ligada[f];
}

+ (BOOL)valida:(DgFeature)f {
    if (f < 0 || f >= DG_TOTAL) return NO;
    return g_valida[f];
}

+ (BOOL)escritaSuportada { return g_escritaOk; }

+ (void)inicializar {
    if (g_iniciado) return;      // roda uma unica vez
    g_iniciado = YES;

    DGLOG(@"[DG] inicializar: comecou");

    @try {
        g_base = [TitanoxHook getBaseAddressOfLibrary:DG_IMAGE_NAME];
    } @catch (NSException *e) {
        g_base = 0;
        DGLOG(@"[DG] excecao ao obter base: %@", e.reason);
    }
    DGLOG(@"[DG] base de %s = 0x%llx", DG_IMAGE_NAME, (unsigned long long)g_base);

    if (g_base == 0) {
        g_erro = @"UnityFramework nao encontrado no processo";
        DGLOG(@"[DG] ERRO: %@", g_erro);
        return;
    }

    int validos = 0;
    for (int i = 0; i < DG_TOTAL; i++) {
        DgAlvo *a = &g_alvos[i];
        uint8_t atual[48] = {0};
        mach_vm_address_t addr = (mach_vm_address_t)(g_base + a->rva);

        DGLOG(@"[DG] [%d/%d] lendo %s em 0x%llx (%zu bytes)",
              i + 1, (int)DG_TOTAL, a->nome, (unsigned long long)addr, a->tam);

        BOOL leu = dgRead((uint64_t)addr, atual, a->tam) ? YES : NO;

        if (!leu) {
            DGLOG(@"[DG] %s: leitura FALHOU em 0x%llx", a->nome, (unsigned long long)addr);
            continue;
        }

        // Os bytes tem de casar com o stub (IPA patchado) ou com o original
        // (IPA limpo). Qualquer outra coisa = versao diferente do jogo -> nao
        // escrever nada nesse alvo.
        if (memcmp(atual, a->stub, a->tam) == 0) {
            g_valida[i] = YES;
            g_ligada[i] = YES;
            validos++;
            DGLOG(@"[DG] %s: OK (estado inicial LIGADO)", a->nome);
        } else if (memcmp(atual, a->original, a->tam) == 0) {
            g_valida[i] = YES;
            g_ligada[i] = NO;
            validos++;
            DGLOG(@"[DG] %s: OK (estado inicial DESLIGADO)", a->nome);
        } else {
            g_valida[i] = NO;
            DGLOG(@"[DG] %s: bytes DESCONHECIDOS em 0x%llx - alvo desabilitado "
                  @"(versao do jogo diferente?)", a->nome, (unsigned long long)addr);
        }
    }

    DGLOG(@"[DG] alvos validos: %d de %d", validos, (int)DG_TOTAL);
    if (validos == 0) {
        g_erro = @"nenhum alvo validou - versao do jogo diferente do dump";
    }
    DGLOG(@"[DG] inicializar: terminou");
}

+ (BOOL)definir:(DgFeature)f ligada:(BOOL)ligar {
    if (f < 0 || f >= DG_TOTAL) return NO;
    if (!g_valida[f]) {
        DGLOG(@"[DG] %s: ignorado (alvo invalido)", g_alvos[f].nome);
        return NO;
    }
    if (g_base == 0) return NO;
    if (g_ligada[f] == ligar) return YES;   // nada a fazer

    DgAlvo *a = &g_alvos[f];
    uint64_t addr = g_base + a->rva;
    uint8_t *dados = ligar ? a->stub : a->original;

    // Pagina de codigo e R-X. dgWrite pede RW (com VM_PROT_COPY), escreve e
    // devolve R-X. E AQUI que o iOS pode dizer nao em app sideloaded - por isso
    // o retorno e conferido e logado.
    if (!dgWrite(addr, dados, a->tam)) {
        g_erro = @"vm_protect/escrita recusada pelo iOS";
        return NO;
    }

    // NAO confiar na escrita: reler e comparar. Se nao bateu, o toggle nao valeu.
    uint8_t conferido[48] = {0};
    if (dgRead(addr, conferido, a->tam) &&
        memcmp(conferido, dados, a->tam) == 0) {
        g_ligada[f] = ligar;
        g_escritaOk = YES;
        DGLOG(@"[DG] %s: agora %s", a->nome, ligar ? "LIGADO" : "DESLIGADO");
        return YES;
    }

    DGLOG(@"[DG] %s: escrita NAO confirmada na releitura", a->nome);
    g_erro = @"escrita em memoria de codigo nao confirmada";
    return NO;
}

+ (NSString *)diagnostico {
    int validos = 0;
    for (int i = 0; i < DG_TOTAL; i++) if (g_valida[i]) validos++;
    return [NSString stringWithFormat:
            @"base 0x%llx | alvos %d/%d | escrita: %@%@",
            (unsigned long long)g_base, validos, (int)DG_TOTAL,
            g_escritaOk ? @"OK" : @"nao testada",
            g_erro ? [@" | " stringByAppendingString:g_erro] : @""];
}

@end
