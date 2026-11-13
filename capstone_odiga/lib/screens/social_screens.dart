part of 'app_screens.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, required this.app});
  final AppState app;
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  String filter = '';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.app,
    builder: (_, _) => AppFrame(
      app: widget.app,
      title: '친구',
      subtitle: '친구들과 취향을 나누고 함께 떠나요',
      showBack: false,
      child: stackItems([
        OdigaSearchField(
          hint: '친구 이름으로 검색',
          onChanged: (v) => setState(() => filter = v),
        ),
        for (final group in widget.app.groups)
          InkWell(
            onTap: () => openPage(
              context,
              GroupScreen(app: widget.app, group: group),
              '/group',
            ),
            child: panel([
              label(group.name, size: 18, bold: true),
              label(
                '${dateText(group.start)} ${clockText(group.start)}',
                size: 11,
              ),
              label(
                '${[widget.app.userName, ...group.friends.map((f) => f.name)].join(' · ')} / ${group.size}명',
                size: 11,
                color: OdigaTokens.muted,
              ),
              label('모임방 열기 →', color: OdigaTokens.brand),
            ], lavender: true),
          ),
        label('내 친구 ${widget.app.friends.length}명', size: 18, bold: true),
        for (final f in widget.app.friends.where(
          (f) => f.name.contains(filter),
        ))
          FriendCard(
            name: f.name,
            initial: f.name.characters.first,
            status: f.status,
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(f.name),
                content: Text(
                  '${f.status}\n${f.tags.map((t) => '#$t').join(' ')}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기'),
                  ),
                ],
              ),
            ),
          ),
        if (!widget.app.friends.any((f) => f.name.contains(filter)))
          label('검색된 친구가 없습니다.'),
        action('+ 친구 초대', () => _invite(context, widget.app), secondary: true),
        action('새 모임 만들기', () async {
          await openPage(
            context,
            _CreateGroupScreen(app: widget.app),
            '/group/create',
          );
          if (mounted) setState(() {});
        }),
      ]),
    ),
  );
}

class _CreateGroupScreen extends StatefulWidget {
  const _CreateGroupScreen({required this.app});

  final AppState app;

  @override
  State<_CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<_CreateGroupScreen> {
  final selected = <String>{};
  var name = '이번 주말 성수 모임';
  late DateTime date = widget.app.conditions.start;
  late String time = clockText(date);

  DateTime? get start {
    final match = RegExp(r'^([01]?[0-9]|2[0-3]):([0-5][0-9])$')
        .firstMatch(time.trim());
    if (match == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(match[1]!),
      int.parse(match[2]!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedule = start;
    return AppFrame(
      app: widget.app,
      title: '새 모임 만들기',
      showBottomNavigation: false,
      child: stackItems([
        TextFormField(
          initialValue: name,
          decoration: const InputDecoration(labelText: '모임 이름'),
          onChanged: (value) => setState(() => name = value.trim()),
        ),
        panel([
          label('일정', bold: true),
          CalendarDatePicker(
            initialDate: date,
            firstDate: DateTime(2020),
            lastDate: DateTime(2099, 12, 31),
            onDateChanged: (value) => setState(() => date = value),
          ),
          TextFormField(
            initialValue: time,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(
              labelText: '방문 시간',
              hintText: '19:00',
              errorText: schedule == null ? '24시간 형식으로 입력해 주세요.' : null,
            ),
            onChanged: (value) => setState(() => time = value),
          ),
        ]),
        panel([
          label('참여자 · 본인 포함 ${selected.length + 1}명', bold: true),
          if (widget.app.friends.isEmpty) label('먼저 친구를 추가해 주세요.'),
          for (final friend in widget.app.friends)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(friend.name),
              value: selected.contains(friend.id),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  selected.add(friend.id);
                } else {
                  selected.remove(friend.id);
                }
              }),
            ),
        ]),
        action(
          '모임 만들기',
          name.isEmpty || selected.isEmpty || schedule == null
              ? null
              : () {
                  final group = widget.app.createGroup(
                    name,
                    selected,
                    schedule,
                  );
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(name: '/group'),
                      builder: (_) =>
                          GroupScreen(app: widget.app, group: group),
                    ),
                  );
                },
        ),
      ]),
    );
  }
}

Future<void> _invite(BuildContext context, AppState app) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('함께 오디가?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label(
          '초대 코드를 복사하거나 데모 친구를 추가해보세요.',
          size: 11,
          color: OdigaTokens.muted,
        ),
        const SizedBox(height: 16),
        panel([
          Center(
            child: label(
              'ODIGA-DEMO',
              size: 18,
              bold: true,
              color: OdigaTokens.brand,
            ),
          ),
        ], lavender: true),
        const SizedBox(height: 12),
        action('초대 코드 복사', () async {
          await Clipboard.setData(const ClipboardData(text: 'ODIGA-DEMO'));
          if (dialogContext.mounted) {
            Navigator.pop(dialogContext);
            toast(context, '데모 초대 코드를 복사했습니다.');
          }
        }),
        const SizedBox(height: 8),
        action('친구의 초대 코드 입력', () async {
          Navigator.pop(dialogContext);
          final code = await editText(
            context,
            '데모 초대 코드',
            initial: 'ODIGA-DEMO',
          );
          if (!context.mounted || code == null) return;
          toast(
            context,
            app.addDemoFriend(code)
                ? '민수님을 예시 친구에 추가했습니다.'
                : '코드가 다르거나 이미 추가한 친구입니다.',
          );
        }, secondary: true),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('닫기'),
      ),
    ],
  ),
);

void _openGroupRecommendations(
  BuildContext context,
  AppState app,
  GroupRoom group, {
  bool expanded = false,
}) {
  final people = group.size;
  if (people > 20) {
    toast(context, '모임 코스는 최대 20명까지 추천할 수 있어요.');
    return;
  }
  openPage(
    context,
    RecommendationsScreen(
      app: app,
      group: true,
      expanded: expanded,
      initialConditions: app.conditions.copy()
        ..start = group.start
        ..people = people
        ..useSelectedRegion = true,
    ),
    '/group/recommendations',
  );
}

class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key, required this.app, required this.group});
  final AppState app;
  final GroupRoom group;
  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모임 삭제'),
        content: Text('‘${group.name}’ 모임과 채팅 기록을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    app.deleteGroup(group);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: app,
    builder: (_, child) => AppFrame(
      app: app,
      title: group.name,
      subtitle: '${group.size}명이 함께 만드는 주말',
      child: stackItems([
        panel([
          label('참여자 ${group.size}명', bold: true),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OdigaAvatar(initial: app.userName.characters.first),
              ...group.friends.map(
                (f) => OdigaAvatar(initial: f.name.characters.first),
              ),
            ],
          ),
        ]),
        panel([
          label(
            '일정 · ${dateText(group.start)} ${clockText(group.start)}',
            size: 18,
            bold: true,
          ),
          label('${app.conditions.region} · ${group.size}명', size: 11),
        ], lavender: true),
        InkWell(
          onTap: () => openPage(
            context,
            ChatScreen(app: app, group: group),
            '/group/chat',
          ),
          child: panel([
            label('최근 대화', bold: true),
            ...group.messages.reversed
                .take(3)
                .toList()
                .reversed
                .map((m) => label('${m.author}   ${m.text}')),
          ]),
        ),
        action(
          '우리에게 맞는 코스 추천받기',
          () => _openGroupRecommendations(context, app, group),
        ),
        action(
          '우리 모임 선호도 보기',
          () => openPage(
            context,
            GroupPreferenceScreen(app: app, group: group),
            '/group/preferences',
          ),
          secondary: true,
        ),
        action(
          '채팅방 열기',
          () => openPage(
            context,
            ChatScreen(app: app, group: group),
            '/group/chat',
          ),
          secondary: true,
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => _confirmDelete(context),
          child: const Text('모임 삭제'),
        ),
      ]),
    ),
  );
}

class GroupPreferenceScreen extends StatelessWidget {
  const GroupPreferenceScreen({
    super.key,
    required this.app,
    required this.group,
  });
  final AppState app;
  final GroupRoom group;
  @override
  Widget build(BuildContext context) {
    final tags = [
      ...app.preference.categories,
      ...app.preference.moods,
      ...group.friends.expand((f) => f.tags),
    ];
    final unique = tags.toSet();
    return AppFrame(
      app: app,
      title: '우리 모임이 좋아하는 것',
      subtitle: '예시 친구들의 취향을 함께 모았어요',
      child: stackItems([
        panel([
          for (final tag in unique) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                label(tag),
                label(
                  '${tags.where((t) => t == tag).length}개 선호',
                  color: OdigaTokens.brand,
                ),
              ],
            ),
            LinearProgressIndicator(
              value: (tags.where((t) => t == tag).length / (group.size)).clamp(
                0,
                1,
              ),
              color: OdigaTokens.brand,
              backgroundColor: OdigaTokens.lavender,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
          ],
        ]),
        label('공통 선호', size: 18, bold: true),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: unique
              .map((t) => OdigaTag(label: '#$t', selected: true))
              .toList(),
        ),
        panel([
          label('✧ 모두의 취향을 균형 있게', color: OdigaTokens.brand),
          label('모임 구성원의 예시 취향과 이동거리를 함께 살펴보세요.'),
        ], lavender: true),
        action(
          '그룹 맞춤 코스 추천받기',
          () => _openGroupRecommendations(context, app, group, expanded: true),
        ),
      ]),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.app, required this.group});
  final AppState app;
  final GroupRoom group;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void send() {
    if (input.text.trim().isEmpty) return;
    widget.app.sendMessage(widget.group, input.text);
    input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.app,
    builder: (_, child) => AppFrame(
      app: widget.app,
      title: widget.group.name,
      subtitle: '참여자 ${widget.group.size}명 · 로컬 예시 채팅',
      scroll: false,
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: widget.group.messages.length,
              separatorBuilder: (_, i) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final m = widget.group.messages[i];
                return panel([
                  label(
                    '${m.author} · ${clockText(m.sentAt)}',
                    size: 11,
                    color: OdigaTokens.muted,
                  ),
                  label(m.text),
                  if (m.course != null)
                    CourseCard(
                      title: m.course!.title,
                      route: m.course!.stops
                          .map(
                            (s) =>
                                widget.app.repository.place(s.placeId).category,
                          )
                          .join(' → '),
                      summary: summary(m.course!),
                      reason: '공유한 코스 · 자세히 보기 ›',
                      congestion: '예시 코스',
                      onTap: () => openPage(
                        context,
                        CourseDetailScreen(app: widget.app, initial: m.course!),
                        '/course/${m.course!.id}',
                      ),
                    ),
                ], lavender: m.author == widget.app.userName);
              },
            ),
          ),
          TextButton(
            onPressed: () =>
                _openGroupRecommendations(context, widget.app, widget.group),
            child: const Text('코스 추천받기'),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => send(),
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  TextButton(onPressed: send, child: const Text('전송 ↑')),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) => AppFrame(
    app: app,
    title: '마이',
    subtitle: '나를 알아갈수록 추천이 더 좋아져요',
    showBack: false,
    child: stackItems([
      panel([
        Row(
          children: [
            OdigaAvatar(initial: app.userName.characters.first),
            const SizedBox(width: 18),
            Expanded(
              child: stackItems([
                label(app.userName, size: 18, bold: true),
                label(
                  '${app.preference.moods.join(' · ')} 분위기를 좋아해요',
                  size: 11,
                  color: OdigaTokens.muted,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () async {
                      final name = await editText(
                        context,
                        '프로필 이름',
                        initial: app.userName,
                      );
                      if (name != null) app.rename(name);
                    },
                    child: const Text('프로필 편집 ›'),
                  ),
                ),
              ], gap: 3),
            ),
          ],
        ),
      ], lavender: true),
      _menu(app.accessToken == null ? '로그인' : '로그아웃', () {
        if (app.accessToken == null) {
          openPage(context, LoginScreen(app: app), '/login');
        } else {
          app.logout();
        }
      }),
      _menu(
        '내 선호도 설정',
        () => openPage(context, PreferencesScreen(app: app), '/preferences'),
      ),
      _menu(
        '저장한 장소',
        () => openPage(context, SavedPlacesScreen(app: app), '/saved-places'),
      ),
      _menu('저장한 코스', () => rootTab(context, app, 1)),
      _menu('친구 관리', () => rootTab(context, app, 2)),
      _menu(
        '프로토타입 안내',
        () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('오디가 프로토타입'),
            content: const Text(
              '지도·장소·혼잡도·추천은 예시입니다.\n저장과 채팅은 앱 실행 중에만 유지됩니다.\n실제 로그인, 카카오맵, AI, 서버는 연결 전입니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        ),
      ),
    ]),
  );
  Widget _menu(String text, VoidCallback onTap) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: ListTile(
      title: label(text),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
      minTileHeight: 62,
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.app});
  final AppState app;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      toast(context, '이메일과 비밀번호를 입력해 주세요.');
      return;
    }
    setState(() => loading = true);
    try {
      await widget.app.login(email.text.trim(), password.text);
      if (!mounted) return;
      toast(context, '로그인했어요.');
      Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) toast(context, error.message);
    } catch (_) {
      if (mounted) toast(context, '로그인하지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppFrame(
    app: widget.app,
    title: '로그인',
    subtitle: '로그인하면 저장한 취향으로 코스를 추천해요',
    child: stackItems([
      panel([
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: '이메일'),
        ),
        TextField(
          controller: password,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => signIn(),
          decoration: const InputDecoration(labelText: '비밀번호'),
        ),
      ]),
      action(loading ? '로그인 중…' : '로그인', loading ? null : signIn),
      label(
        '현재는 예시 로그인입니다. 서버 연결 후 실제 계정으로 로그인할 수 있어요.',
        size: 11,
        color: OdigaTokens.muted,
      ),
    ]),
  );
}

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key, required this.app});
  final AppState app;
  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  static const _moods = ['조용한', '활기찬', '감성적인', '가성비좋은', '넓고편한', '뷰좋은'];
  static const _cuisines = <String, List<String>>{
    '한식': ['고기', '국밥', '찌개·전골', '국수', '해물·생선'],
    '일식': ['초밥·롤', '라멘', '돈까스·우동', '덮밥'],
    '양식': ['이탈리안', '피자', '햄버거', '스테이크', '멕시칸'],
    '중식': ['중국요리', '양꼬치'],
    '분식': ['떡볶이', '김밥'],
    '아시아': ['동남아', '인도'],
    '치킨': [],
    '술집': ['호프·요리주점', '이자카야', '칵테일바', '와인바', '포장마차'],
    '카페·디저트': ['디저트카페', '개인카페', '프랜차이즈', '갤러리·북카페', '차·음료'],
  };
  bool saving = false;
  late final draft = widget.app.preference.copy();

  Widget choices(List<String> options, Set<String> selected) => Wrap(
    spacing: 6,
    runSpacing: 8,
    children: options
        .map(
          (v) => OdigaTag(
            label: v,
            selected: selected.contains(v),
            onSelected: (value) => setState(() {
              if (value) {
                selected.add(v);
              } else {
                selected.remove(v);
              }
            }),
          ),
        )
        .toList(),
  );

  Widget moodChoices() => Wrap(
    spacing: 6,
    runSpacing: 8,
    children: _moods
        .map(
          (mood) => OdigaTag(
            label: mood,
            selected: draft.moods.contains(mood),
            onSelected: (selected) => setState(() {
              if (selected) {
                draft.moods.add(mood);
              } else {
                draft.moods.remove(mood);
              }
            }),
          ),
        )
        .toList(),
  );
  @override
  Widget build(BuildContext context) => AppFrame(
    app: widget.app,
    title: '내 취향을 알려주세요',
    subtitle: '추천에 반영할 관심사와 조건',
    child: stackItems([
      label('음식 취향', size: 18, bold: true),
      label('큰 종류를 고르면 세부 취향을 선택할 수 있어요.', size: 11, color: OdigaTokens.muted),
      for (final entry in _cuisines.entries)
        panel([
          OdigaTag(
            label: entry.key,
            selected: draft.cuisines.contains(entry.key),
            onSelected: (selected) => setState(() {
              if (selected) {
                draft.cuisines.add(entry.key);
              } else {
                draft.cuisines.remove(entry.key);
                draft.cuisineDetails.removeAll(entry.value.toSet());
              }
            }),
          ),
          if (draft.cuisines.contains(entry.key) && entry.value.isNotEmpty)
            choices(entry.value, draft.cuisineDetails),
        ], lavender: draft.cuisines.contains(entry.key)),
      label('좋아하는 분위기', size: 18, bold: true),
      moodChoices(),
      label(
        '활기찬을 고르면 사람 많은 곳을 선호하는 조건으로 반영해요.',
        size: 11,
        color: OdigaTokens.muted,
      ),
      action(
        saving ? '저장 중…' : '선호도 저장',
        saving
            ? null
            : () async {
                setState(() => saving = true);
                try {
                  await widget.app.savePreference(draft);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  toast(context, '선호도를 저장했습니다.');
                } on ApiException catch (e) {
                  if (context.mounted) toast(context, e.message);
                } finally {
                  if (mounted) setState(() => saving = false);
                }
              },
      ),
    ]),
  );
}
