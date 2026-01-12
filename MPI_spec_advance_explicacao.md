# Paralelização com MPI da função spec_advance

## Introdução

A função `spec_advance()` é o coração da simulação de partículas. Ela realiza o avanço temporal de todas as partículas usando o método de leap-frog com acelerador relativista de Boris. Na versão original (sequencial), uma única processo executava todo o trabalho. Na versão paralela com MPI, o trabalho é distribuído entre múltiplos processos (ranks) para acelerar a computação.

---

## Comparação: Sequencial vs Paralelo

### Versão Sequencial (Original)

Na versão original, a função:
1. Itera sobre TODAS as partículas (`for (int i=0; i<spec->np; i++)`)
2. Avança cada partícula individualmente usando Boris pusher
3. Deposita a corrente de cada partícula no grid global `current->J`
4. Aplica condições de fronteira (absorventes ou periódicas)
5. Classifica as partículas se necessário
6. Tudo em um único processo sequencial

**Problema**: Com milhões de partículas, isto é muito lento!

### Versão Paralela com MPI (Atual)

Na versão paralela, o trabalho é distribuído:
1. **Distribuição de partículas**: Cada rank processa um subconjunto de partículas
2. **Buffers locais**: Cada rank deposita corrente num buffer local (sem contenção)
3. **Redução de dados**: Os resultados são combinados com `MPI_Allreduce`
4. **Sincronização de partículas**: Todos os ranks recebem as atualizações de todos os outros
5. **Condições de fronteira**: Rank 0 processa e broadcast para os outros
6. **Classificação**: Rank 0 classifica e broadcast para os outros

---

## Detalhes da Implementação Paralela

### 1. Obter Informações de Rank e Tamanho

```c
int rank, size;
MPI_Comm_rank(MPI_COMM_WORLD, &rank);
MPI_Comm_size(MPI_COMM_WORLD, &size);
```

Cada processo MPI descobre a sua identidade (rank) e quantos processos existem no total (size).

### 2. Distribuição de Partículas Entre Ranks

```c
int np_total = spec->np;
int particles_per_rank = np_total / size;
int remainder = np_total % size;

int start_idx = rank * particles_per_rank + (rank < remainder ? rank : remainder);
int end_idx = start_idx + particles_per_rank + (rank < remainder ? 1 : 0);
```

**Estratégia de distribuição equilibrada:**
- Cada rank recebe `particles_per_rank = np_total / size` partículas
- Se houver resto na divisão, os primeiros `remainder` ranks recebem 1 partícula extra
- Exemplo com 1000 partículas e 3 ranks:
  - Rank 0: partículas 0-333 (334 partículas)
  - Rank 1: partículas 334-667 (334 partículas)
  - Rank 2: partículas 668-999 (333 partículas)

**Benefício**: Carga de trabalho bem equilibrada entre todos os ranks.

#### Como Funciona a Distribuição do Remainder

A fórmula utiliza aritmética inteligente para distribuir o resto de forma equilibrada:

```
np_total = 1000 partículas
size = 3 ranks

particles_per_rank = 1000 / 3 = 333
remainder = 1000 % 3 = 1
```

**Cálculo de `start_idx` para cada rank:**

Para cada rank `r`:
```
start_idx[r] = r * particles_per_rank + (r < remainder ? r : remainder)
```

Vamos ver passo a passo:

- **Rank 0** (`r = 0`):
  - `0 < 1` ? **SIM** → usar `0`
  - `start_idx = 0 * 333 + 0 = 0`

- **Rank 1** (`r = 1`):
  - `1 < 1` ? **NÃO** → usar `remainder = 1`
  - `start_idx = 1 * 333 + 1 = 334`

- **Rank 2** (`r = 2`):
  - `2 < 1` ? **NÃO** → usar `remainder = 1`
  - `start_idx = 2 * 333 + 1 = 667`

**Cálculo de `end_idx` para cada rank:**

```
end_idx[r] = start_idx[r] + particles_per_rank + (r < remainder ? 1 : 0)
```

- **Rank 0**:
  - `0 < 1` ? **SIM** → adicionar 1
  - `end_idx = 0 + 333 + 1 = 334`
  - **Partículas**: [0, 334) = **334 partículas**

- **Rank 1**:
  - `1 < 1` ? **NÃO** → adicionar 0
  - `end_idx = 334 + 333 + 0 = 667`
  - **Partículas**: [334, 667) = **333 partículas**

- **Rank 2**:
  - `2 < 1` ? **NÃO** → adicionar 0
  - `end_idx = 667 + 333 + 0 = 1000`
  - **Partículas**: [667, 1000) = **333 partículas**

**Resultado final:**
```
Total: 334 + 333 + 333 = 1000 ✓
```

#### Visualização Gráfica

```
Partículas:  0 ├─────────────────────────────────────────────────────┤ 999
             │                                                        │
Rank 0:      ├──── 334 partículas ────┤ (0 a 333)
Rank 1:                               ├──── 333 partículas ────┤ (334 a 666)
Rank 2:                                                        ├──── 333 partículas ────┤ (667 a 999)
```

#### Outro Exemplo: 10 Partículas, 4 Ranks

```
np_total = 10
size = 4

particles_per_rank = 10 / 4 = 2
remainder = 10 % 4 = 2
```

Distribuição:

| Rank | Condição `r < remainder` | start_idx | end_idx | Partículas | Count |
|------|--------------------------|-----------|---------|------------|-------|
| 0    | 0 < 2 ✓                  | 0         | 3       | [0, 3)     | **3** |
| 1    | 1 < 2 ✓                  | 3         | 6       | [3, 6)     | **3** |
| 2    | 2 < 2 ✗                  | 6         | 8       | [6, 8)     | **2** |
| 3    | 3 < 2 ✗                  | 8         | 10      | [8, 10)    | **2** |

**Total**: 3 + 3 + 2 + 2 = 10 ✓

#### Por Que Este Método?

1. **Simples**: Apenas uma fórmula, sem loops
2. **Eficiente**: O(1) para calcular qualquer intervalo
3. **Equilibrado**: O resto é distribuído entre os primeiros `remainder` ranks
4. **Contíguo**: Cada rank recebe um intervalo contíguo (melhor cache)
5. **Sem lacunas**: Todos os ranks recebem partículas, nenhuma é perdida

#### Caso Especial: Remainder = 0

Se `np_total` é divisível por `size`:

```
np_total = 1000, size = 4
particles_per_rank = 250
remainder = 0
```

Todos os ranks recebem exatamente 250 partículas (nenhuma extra):
- Rank 0: [0, 250)
- Rank 1: [250, 500)
- Rank 2: [500, 750)
- Rank 3: [750, 1000)

### 3. Buffers Locais para Evitar Contenção

```c
int J_size = current->gc[0] + current->nx + current->gc[1];
float3 *local_J = (float3*) malloc(J_size * sizeof(float3));

// Inicializar buffer local
for (int j = 0; j < J_size; j++) {
    local_J[j].x = 0.0f;
    local_J[j].y = 0.0f;
    local_J[j].z = 0.0f;
}

// Estrutura local que aponta para o buffer local
t_current local_current = *current;
local_current.J_buf = local_J;
local_current.J = local_J + current->gc[0];
```

**Problema evitado**: Se todos os ranks depositassem diretamente no array global `current->J`, haveria data races (múltiplos ranks escrevendo simultaneamente na mesma memória).

**Solução**: Cada rank tem o seu próprio buffer `local_J` onde deposita a corrente independentemente. Posteriormente, os resultados são combinados com `MPI_Allreduce`.

**Benefício**: Não há sincronização dentro do loop de avanço de partículas, maximizando o paralelismo.

### 4. Avanço de Partículas com Boris Pusher

```c
for (int i = start_idx; i < end_idx; i++) {
    // Boris pusher: atualizar velocidade e posição
    // ... cálculos do Boris pusher ...
    
    // Depositar corrente no buffer LOCAL
    dep_current_zamb( spec -> part[i].ix, di,
                     spec -> part[i].x, dx,
                     qnx, qvy, qvz,
                     &local_current );  // Buffer local, não global
    
    // Atualizar posição da partícula
    spec -> part[i].x = x1;
    spec -> part[i].ix += di;
}
```

**Mudança importante**: 
- Na versão sequencial: deposita em `current` (global)
- Na versão paralela: deposita em `&local_current` (local ao rank)

Cada partícula é avançada exatamente da mesma forma, mas o local de deposição da corrente é diferente.

### 5. Redução de Dados: Combinando Resultados Locais

```c
// Reduzir buffers de corrente local em todos os ranks
float3 *reduced_J = (float3*) malloc(J_size * sizeof(float3));
MPI_Allreduce(local_J, reduced_J, J_size * 3, MPI_FLOAT, MPI_SUM, MPI_COMM_WORLD);

// Adicionar resultado reduzido à corrente global
for (int j = 0; j < J_size; j++) {
    current->J_buf[j].x += reduced_J[j].x;
    current->J_buf[j].y += reduced_J[j].y;
    current->J_buf[j].z += reduced_J[j].z;
}
free(reduced_J);
```

**O que acontece:**
- `MPI_Allreduce` combina os buffers locais de todos os ranks usando SUM
- Cada elemento `local_J[j]` de cada rank é somado com o correspondente dos outros ranks
- O resultado é retornado em `reduced_J` em TODOS os ranks
- Adicionamos o resultado à corrente global (preserva contribuições de outras espécies)

**Fórmula matemática:**
$$\text{reduced\_J}[j] = \sum_{\text{rank}=0}^{\text{size}-1} \text{local\_J}[j]_{\text{rank}}$$

**Benefício**: Combina os resultados sem conflitos de acesso à memória.

### 6. Redução de Energia

```c
double local_energy = 0;

// Durante o loop: acumular energia local
local_energy += u2 / ( 1 + gamma );

// Após o loop: reduzir energia global
MPI_Allreduce(&local_energy, &energy, 1, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);
```

De forma similar à corrente, cada rank calcula a energia das suas partículas e depois todas são somadas.

### 7. Sincronização de Dados de Partículas

```c
// Criar tipo de dados MPI para t_part (estrutura)
MPI_Datatype MPI_PARTICLE;
MPI_Type_contiguous(sizeof(t_part), MPI_BYTE, &MPI_PARTICLE);
MPI_Type_commit(&MPI_PARTICLE);

// Cada rank faz broadcast das suas partículas para todos os outros
for (int r = 0; r < size; r++) {
    int r_particles = particles_per_rank + (r < remainder ? 1 : 0);
    int r_start = r * particles_per_rank + (r < remainder ? r : remainder);
    
    MPI_Bcast(&spec->part[r_start], r_particles, MPI_PARTICLE, r, MPI_COMM_WORLD);
}

MPI_Type_free(&MPI_PARTICLE);
```

**Por que é necessário?**

Embora cada rank avance o seu subconjunto de partículas, as condições de fronteira e outras operações podem depender de TODAS as partículas. Assim, todos os ranks precisam ter dados atualizados de todas as partículas.

**Como funciona:**
1. Define um tipo MPI que representa uma estrutura `t_part` como um blob de bytes
2. Rank 0 faz broadcast das suas partículas para todos
3. Rank 1 faz broadcast das suas partículas para todos
4. ... repetir para todos os ranks
5. No final, todos os ranks têm o array completo de partículas atualizado

**Analogia**: É como se cada pessoa numa sala tivesse alguns documentos e, um a um, fizesse cópias para toda a gente.

### 8. Condições de Fronteira

```c
if ( spec -> moving_window || spec -> bc_type == PART_BC_OPEN ){
    // Janela móvel ou fronteiras absorventes (operação destrutiva)
    
    if (rank == 0) {
        // Apenas rank 0 remove partículas fora do domínio
        int i = 0;
        while ( i < spec -> np ) {
            if (( spec -> part[i].ix < 0 ) || ( spec -> part[i].ix >= nx0 )) {
                spec -> part[i] = spec -> part[ -- spec -> np ];
                continue;
            }
            i++;
        }
    }
    
    // Broadcast número atualizado de partículas
    MPI_Bcast(&spec->np, 1, MPI_INT, 0, MPI_COMM_WORLD);
    
    // Broadcast array atualizado de partículas
    MPI_Datatype MPI_PARTICLE_BC;
    MPI_Type_contiguous(sizeof(t_part), MPI_BYTE, &MPI_PARTICLE_BC);
    MPI_Type_commit(&MPI_PARTICLE_BC);
    MPI_Bcast(spec->part, spec->np, MPI_PARTICLE_BC, 0, MPI_COMM_WORLD);
    MPI_Type_free(&MPI_PARTICLE_BC);
} else {
    // Fronteiras periódicas (operação determinística)
    for (int i=0; i<spec->np; i++) {
        spec -> part[i].ix += (( spec -> part[i].ix < 0 ) ? nx0 : 0 ) - 
                              (( spec -> part[i].ix >= nx0 ) ? nx0 : 0);
    }
}
```

**Distinção importante:**

**Fronteiras Absorventes (PART_BC_OPEN)**:
- Partículas que saem do domínio são eliminadas (operação destrutiva)
- Modificam o número total de partículas `spec->np`
- Devem ser processadas por um único rank (rank 0) para evitar inconsistências
- Resultado é broadcast para todos os outros

**Fronteiras Periódicas (PART_BC_PERIODIC)**:
- Partículas que saem de um lado voltam pelo outro (operação determinística)
- Não modificam o número de partículas
- Cada rank pode fazer isto independentemente (mesma matemática = mesmo resultado)
- Não requer comunicação MPI

**Otimização**: O broadcast de `spec->np` está dentro do `if`, portanto é feito apenas para fronteiras absorventes, não para periódicas.

### 9. Classificação de Partículas

```c
if ( spec -> n_sort > 0 ) {
    if ( ! (spec -> iter % spec -> n_sort) ) {
        // Classificação feita apenas por rank 0
        if (rank == 0) spec_sort( spec );
        
        // Broadcast array classificado
        MPI_Datatype MPI_PARTICLE_SORT;
        MPI_Type_contiguous(sizeof(t_part), MPI_BYTE, &MPI_PARTICLE_SORT);
        MPI_Type_commit(&MPI_PARTICLE_SORT);
        MPI_Bcast(spec->part, spec->np, MPI_PARTICLE_SORT, 0, MPI_COMM_WORLD);
        MPI_Type_free(&MPI_PARTICLE_SORT);
    }
}
```

De forma similar às condições de fronteira:
- Rank 0 classifica as partículas para otimizar localidade de cache
- Resultado é broadcast para todos os outros ranks manterem o array sincronizado

---

## Resumo das Operações MPI Utilizadas

| Operação | Descrição | Quando Usada |
|----------|-----------|-------------|
| `MPI_Comm_rank()` | Obter identificador do processo | No início da função |
| `MPI_Comm_size()` | Obter número total de processos | No início da função |
| `MPI_Allreduce()` | Combinar valores locais de todos os ranks | Corrente e energia |
| `MPI_Bcast()` | Um rank envia dados para todos os outros | Partículas e estado |

---

## Fluxo de Execução

```
┌─────────────────────────────────────────────────────┐
│ spec_advance() chamada em TODOS os ranks             │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│ 1. Calcular intervalo de partículas para este rank   │
│    (distribuição equilibrada)                       │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│ 2. Criar buffer local de corrente (sem contenção)   │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│ 3. Loop: Avançar partículas locais com Boris pusher │
│    Depositar corrente no buffer LOCAL               │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│ 4. MPI_Allreduce: Combinar correntes de todos ranks │
│    Resultado em todos os ranks                      │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│ 5. MPI_Allreduce: Combinar energia de todos ranks   │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│ 6. Broadcast em loop: Sincronizar partículas        │
│    Cada rank envia as suas para todos               │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│ 7. Condições de Fronteira:                          │
│    - Se absorventes: Rank 0 remove, broadcast      │
│    - Se periódicas: Todos fazem independentemente  │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│ 8. Se necessário: Rank 0 classifica, broadcast     │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│ spec_advance() termina em TODOS os ranks             │
│ (Todos têm dados sincronizados)                     │
└─────────────────────────────────────────────────────┘
```

---

## Benefícios da Paralelização

| Aspecto | Ganho |
|--------|-------|
| **Velocidade** | Múltiplos processos trabalham em paralelo, reduzindo tempo total |
| **Escalabilidade** | Pode usar mais processadores para problemas maiores |
| **Eficiência** | Cada rank processa uma porção mais pequena de partículas |
| **Memória** | Distribuída entre nós (em computação distribuída) |

---

## Desafios e Soluções

| Desafio | Solução Implementada |
|---------|---------------------|
| **Data Races** | Buffers locais por rank, depois redução |
| **Inconsistência de Estado** | Broadcasts para manter sincronismo |
| **Operações Destrutivas** | Apenas rank 0 as executa, depois broadcast |
| **Carga Desigual** | Distribuição equilibrada com resto |
| **Estruturas Complexas** | Tipos MPI personalizados com `MPI_Type_contiguous` |

---

## Conclusão

A paralelização com MPI da função `spec_advance()` transforma um algoritmo sequencial em um verdadeiramente paralelo, permitindo simular plasmas com milhões de partículas em tempo razoável. A estratégia utiliza:

1. **Paralelismo de dados**: Cada rank processa um subconjunto de partículas
2. **Localidade**: Buffers locais evitam sincronização frequente
3. **Sincronização estratégica**: Apenas quando necessário (redução e broadcast)
4. **Distinção de operações**: Determinísticas vs destrutivas tratadas diferentemente

Este design é um exemplo clássico de computação científica paralela eficiente.
