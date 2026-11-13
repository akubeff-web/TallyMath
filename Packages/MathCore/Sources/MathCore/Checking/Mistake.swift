/// Типичные ошибки. Для каждой — короткая реплика Bit и подсказка к шагу.
/// Подсказка объясняет правило, но не выдаёт готовый ответ.
public enum MistakeKind: String, Sendable, Codable, CaseIterable, Hashable {
    case addedTopsAndBottoms
    case multipliedOnlyTop
    case multipliedOnlyBottom
    case dividedOnlyTop
    case dividedOnlyBottom
    case forgotWholePart
    case wrongCommonDenominator
    case signError
    case minusBeforeBracket
    case squareMissingDoubleProduct
    case cancelledTerms
    case divisionNotFlipped
    case powersMultiplied
    case powersAdded
    case decimalPoint
    case neighbourTableFact
    case remainderTooBig
    case extraneousRoot
    case lostRoot
    case rootsSignSwapped
    case inequalityNotFlipped
    case intervalBracket
    case transferWithoutSignChange
    case dividedOneSide
    case annotationNotApplied
    case arithmetic

    public var title: String {
        switch self {
        case .addedTopsAndBottoms: return "Низ не складываем."
        case .multipliedOnlyTop: return "Умножил только верх."
        case .multipliedOnlyBottom: return "Умножил только низ."
        case .dividedOnlyTop: return "Поделил только верх."
        case .dividedOnlyBottom: return "Поделил только низ."
        case .forgotWholePart: return "Потерял целую часть."
        case .wrongCommonDenominator: return "Общий низ не делится на оба низа."
        case .signError: return "Ошибка в знаке."
        case .minusBeforeBracket: return "Минус перед скобкой меняет все знаки."
        case .squareMissingDoubleProduct: return "Забыл удвоенное произведение."
        case .cancelledTerms: return "Сократил слагаемые."
        case .divisionNotFlipped: return "При делении вторую дробь переворачивают."
        case .powersMultiplied: return "При умножении показатели складывают."
        case .powersAdded: return "Степень в степени — показатели умножают."
        case .decimalPoint: return "Запятая не на месте."
        case .neighbourTableFact: return "Это соседний пример таблицы."
        case .remainderTooBig: return "Остаток больше делителя."
        case .extraneousRoot: return "Лишний корень."
        case .lostRoot: return "Потерян корень."
        case .rootsSignSwapped: return "Перепутаны знаки корней."
        case .inequalityNotFlipped: return "Знак неравенства не сменил."
        case .intervalBracket: return "Скобка не та."
        case .transferWithoutSignChange: return "Перенёс без смены знака."
        case .dividedOneSide: return "Поделил только одну часть."
        case .annotationNotApplied: return "Множитель применён не к верху и низу."
        case .arithmetic: return "Ошибка в вычислении."
        }
    }

    public var hint: String {
        switch self {
        case .addedTopsAndBottoms:
            return "Складывают только верхи, низ остаётся общим. Сначала сделай низы одинаковыми."
        case .multipliedOnlyTop, .multipliedOnlyBottom:
            return "Чтобы дробь не изменилась, верх и низ умножают на одно и то же число."
        case .dividedOnlyTop, .dividedOnlyBottom:
            return "Сокращая, делят и верх, и низ на одно и то же число."
        case .forgotWholePart:
            return "Когда выделяешь целую часть, она остаётся в ответе: целая часть и дробь."
        case .wrongCommonDenominator:
            return "Общий низ должен делиться на каждый низ. Проще всего взять наименьшее общее кратное."
        case .signError:
            return "Проверь знаки: минус на минус даёт плюс, вычитание числа — это прибавление противоположного."
        case .minusBeforeBracket:
            return "−(a + b) = −a − b. Минус перед скобкой меняет знак каждого слагаемого внутри."
        case .squareMissingDoubleProduct:
            return "(a + b)² = a² + 2ab + b². Средний член 2ab легко потерять."
        case .cancelledTerms:
            return "Сокращать можно только множители, а не слагаемые. Сначала разложи на множители."
        case .divisionNotFlipped:
            return "a/b : c/d = a/b · d/c. Вторую дробь переворачивают и умножают."
        case .powersMultiplied:
            return "aᵐ · aⁿ = aᵐ⁺ⁿ. При умножении степеней с одинаковым основанием показатели складывают."
        case .powersAdded:
            return "(aᵐ)ⁿ = aᵐⁿ. При возведении степени в степень показатели умножают."
        case .decimalPoint:
            return "Посчитай, сколько знаков после запятой у множителей, — столько же будет в ответе."
        case .neighbourTableFact:
            return "Проверь, какие числа умножаешь. Можно прибавить или отнять одно число от соседнего факта."
        case .remainderTooBig:
            return "Остаток всегда меньше делителя. Если больше — частное можно увеличить."
        case .extraneousRoot:
            return "Подставь корни в знаменатели: при каком-то из них знаменатель равен нулю, такой корень не подходит."
        case .lostRoot:
            return "Корней может быть два. Проверь, не делил ли на выражение с переменной и не пропустил ли «±»."
        case .rootsSignSwapped:
            return "По теореме Виета x₁ + x₂ = −b/a. Проверь знак суммы корней."
        case .inequalityNotFlipped:
            return "При умножении или делении на отрицательное число знак неравенства меняется на противоположный."
        case .intervalBracket:
            return "Квадратная скобка — точка входит (≤, ≥), круглая — не входит (<, >). У бесконечности всегда круглая."
        case .transferWithoutSignChange:
            return "Слагаемое переносят в другую часть с противоположным знаком."
        case .dividedOneSide:
            return "Обе части уравнения делят на одно и то же число."
        case .annotationNotApplied:
            return "Дополнительный множитель умножает и верх, и низ дроби."
        case .arithmetic:
            return "Пересчитай действие ещё раз, медленно."
        }
    }
}

/// Найденная ошибка: вид и, если удалось, уточнение на числах примера.
public struct MistakeReport: Sendable, Equatable, Hashable {
    public var kind: MistakeKind
    public var detail: String?

    public init(_ kind: MistakeKind, detail: String? = nil) {
        self.kind = kind
        self.detail = detail
    }

    /// Короткая реплика Bit.
    public var message: String { detail ?? kind.title }
}

/// Почему верный ответ ещё не в простейшем виде.
public enum SimplestIssue: Sendable, Equatable, Hashable {
    case reduce(by: Int?)
    case extractWhole
    case finishComputation
    case combineLikeTerms
    case factorFurther
    case notFactored
    case writeAsInterval
    case standardForm
    case writeAsDecimal
    case simplifyRadical
    case writeAsImproper

    public var message: String {
        switch self {
        case .reduce(let k?): return "Верно, но сократи на \(k)."
        case .reduce(nil): return "Верно, но сократи."
        case .extractWhole: return "Верно, но выдели целую часть."
        case .finishComputation: return "Верно, но досчитай до числа."
        case .combineLikeTerms: return "Верно, но приведи подобные."
        case .factorFurther: return "Верно, но можно разложить дальше."
        case .notFactored: return "Верно, но нужно произведение множителей."
        case .writeAsInterval: return "Верно, но запиши ответ промежутком."
        case .standardForm: return "Верно, но в стандартном виде 1 ≤ a < 10."
        case .writeAsDecimal: return "Верно, но нужна десятичная дробь."
        case .simplifyRadical: return "Верно, но вынеси множитель из-под корня."
        case .writeAsImproper: return "Верно, но нужна неправильная дробь."
        }
    }
}

/// Статус строки решения или ответа.
public enum LineStatus: Sendable, Equatable, Hashable {
    case correct
    case correctNotSimplest(SimplestIssue)
    case wrong(MistakeReport?)
    case unverifiable(String)

    public var isCorrect: Bool {
        switch self {
        case .correct, .correctNotSimplest: return true
        default: return false
        }
    }

    public var message: String {
        switch self {
        case .correct: return "Верно."
        case .correctNotSimplest(let i): return i.message
        case .wrong(let m?): return m.message
        case .wrong(nil): return "Неверно."
        case .unverifiable(let why): return "Не удалось проверить этот шаг: \(why)"
        }
    }
}
