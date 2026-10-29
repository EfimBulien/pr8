#include <cstdlib>
#include <ctime>
#include <iomanip>
#include <iostream>
#include <limits>
#include <random>

const unsigned short MAX_DIM = 100;
const signed int MIN_VALUE = -1000;
const unsigned int MAX_VALUE = 1000;

int validateInput(const char *user_input, int start, int end)
{
    int value;
    while (true)
    {
        std::cout << user_input << " число от " << start << " до " << end << ": ";

        if (std::cin >> value)
        {
            if (value >= start && value <= end)
            {
                std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
                return value;
            }
            std::cout << "Ошибка: число вне допустимого диапазона.\n";
        }
        else
        {
            if (std::cin.eof())
            {
                std::cout << "\nВвод завершён. Выход из программы.\n";
                std::exit(0);
            }

            std::cout << "Ошибка: нужно ввести целое число.\n";
            std::cin.clear();
        }

        std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    }
}

inline void inputSize(int &n, int &m)
{
    n = validateInput("Введите количество строк n", 1, MAX_DIM);
    m = validateInput("Введите количество столбцов m", 1, MAX_DIM);
}

void fillManual(int a[][MAX_DIM], int n, int m)
{
    std::cout << "Введите элементы массива " << n << "x" << m << "\n";

    for (int i = 0; i < n; ++i)
    {
        for (int j = 0; j < m; ++j)
        {
            std::cout << "Элемент a" << i + 1 << j + 1;
            a[i][j] = validateInput("", MIN_VALUE, MAX_VALUE);
        }
    }
}

static void fillRandom(int a[][MAX_DIM], int n, int m)
{
    static std::mt19937 gen(std::random_device{}());
    std::uniform_int_distribution<int> dist(MIN_VALUE, MAX_VALUE);

    for (int i = 0; i < n; ++i)
        for (int j = 0; j < m; ++j)
            a[i][j] = dist(gen);
}

inline void printArray(const int a[][MAX_DIM], int n, int m)
{
    std::cout << "Массив " << n << "x" << m << ":\n";
    for (int i = 0; i < n; ++i)
    {
        for (int j = 0; j < m; ++j) 
            std::cout << std::setw(7) << a[i][j];
        std::cout << '\n';
    }
}

void calcAvgBelowDiagAndMainDiagArray(const int a[][MAX_DIM], int n, int m)
{
    long long sumNegBelow = 0;
    int countNegBelow = 0;
    long long sumDiag = 0;
    unsigned int countDiag = 0;

    for (int i = 0; i < n; ++i)
    {
        for (int j = 0; j < m; ++j)
        {
            if (i == j)
            {
                sumDiag += a[i][j];
                ++countDiag;
            }
            else if (i > j && a[i][j] < 0)
            {
                sumNegBelow += a[i][j];
                ++countNegBelow;
            }
        }
    }

    std::cout << std::fixed << std::setprecision(3);
    if (countNegBelow > 0)
    {
        std::cout << "Среднее арифметическое отрицательных элементов ниже главной диагонали ("
                  << countNegBelow << ") = "
                  << static_cast<double>(sumNegBelow) / countNegBelow 
                  << '\n';
    }
    else std::cout << "Отрицательных элементов ниже главной диагонали нет, среднее не определено.\n";
    
    // countDiag >= 1 так как n >= 1 и m >= 1
    std::cout << "Среднее арифметическое элементов главной диагонали ("
              << countDiag << ") = "
              << static_cast<double>(sumDiag) / countDiag
              << '\n';
}

static inline void printMenu()
{
    std::cout << "\nДействия с массивом\n"
              << "1. Задать размеры массива заново\n"
              << "2. Заполнить массив вручную\n"
              << "3. Заполнить массив случайными числами\n"
              << "4. Вывести массив\n"
              << "5. Выполнить задание\n"
              << "0. Выход\n";
}

int main()
{
    int n, m;
    int a[MAX_DIM][MAX_DIM];
    
    inputSize(n, m);

    bool filled = false;
    while (true)
    {
        printMenu();
        const int choice = validateInput("Ваш выбор", 0, 5);

        switch (choice)
        {
        case 1:
            inputSize(n, m);
            filled = false;
            std::cout << "Размеры изменены. Заполните массив заново.\n";
            break;
        case 2:
            fillManual(a, n, m);
            filled = true;
            break;
        case 3:
            fillRandom(a, n, m);
            filled = true;
            std::cout << "Массив заполнен случайными числами.\n";
            break;
        case 4:
            if (!filled) std::cout << "Массив ещё не заполнен.\n"; 
            else printArray(a, n, m);
            break;
        case 5:
            if (!filled) std::cout << "Массив ещё не заполнен.\n";
            else
            {
                printArray(a, n, m);
                calcAvgBelowDiagAndMainDiagArray(a, n, m);
            }
            break;
        case 0:
            std::cout << "Завершение работы.\n";
            return 0;
        default:
            std::cout << "Неверный пункт меню.\n";
        }
    }
}
