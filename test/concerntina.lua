local lu = require('luaunit')
local goto_window = require('test/helper').goto_window
local heights = require('test/helper').heights
local exec = require('test/helper').exec
local stretched_windows = require('test/helper').stretched_windows

-- max window height = 22 (no windows above or below)
-- separator height between windows = 1 (bar between them)
-- min window height = 0 (collapsed)

-- +-----+
-- |  1  |
-- +-----+
-- |  2  |
-- +-----+
function test_two_horizontal_windows()
  exec({'%bwipe!', 'split'})
  lu.assertItemsEquals(stretched_windows(), {1, 2})
  goto_window(1)
  lu.assertEquals(heights(), {21, 0})
  goto_window(2)
  lu.assertEquals(heights(), {0, 21})
  goto_window(1)
  lu.assertEquals(heights(), {21, 0})
end

-- +-----------+
-- |  1  |  2  |
-- +-----------+
function test_two_vertical_windows()
  exec({'%bwipe!', 'vsplit'})
  lu.assertItemsEquals(stretched_windows(), {})
  goto_window(1)
  lu.assertEquals(heights(), {22, 22})
  goto_window(2)
  lu.assertEquals(heights(), {22, 22})
end

-- +------+
-- |  1   |
-- +------+
-- | 2 qf |
-- +------+
function test_window_with_horizontal_qf()
  exec({'%bwipe!', 'copen'})
  lu.assertItemsEquals(stretched_windows(), {1, 2})
  goto_window(1)
  lu.assertEquals(heights(), {11, 10})
  goto_window(2)
  lu.assertEquals(heights(), {11, 10})
  goto_window(1)
  lu.assertEquals(heights(), {11, 10})
end

-- +------------+
-- |  1  | 2 qf |
-- +------------+
function test_window_with_vertical_qf()
  exec({'%bwipe!', 'copen | wincmd L'})
  lu.assertItemsEquals(stretched_windows(), {})
  goto_window(1)
  lu.assertEquals(heights(), {22, 22})
  goto_window(2)
  lu.assertEquals(heights(), {22, 22})
end

-- +------+
-- |  1   |
-- +------+
-- |  2   |
-- +------+
-- | 3 qf |
-- +------+
function test_two_horizontal_windows_with_horizontal_qf()
  exec({'%bwipe!', 'split', 'copen'})
  lu.assertItemsEquals(stretched_windows(), {1, 2, 3})
  goto_window(1)
  lu.assertEquals(heights(), {10, 0, 10})
  goto_window(2)
  lu.assertEquals(heights(), {0, 10, 10})
  goto_window(3)
  lu.assertEquals(heights(), {10, 0, 10}, 'TODO keep window 2 focused as it was focused before entering the qf')
end

-- +-----+------+
-- |     |  2   |
-- |     +------+
-- |  1  |  3   |
-- |     +------+
-- |     | 4 qf |
-- +-----+------+
function test_three_windows_with_qf()
  exec({'%bwipe!', 'split', 'copen', 'vsplit', 'wincmd H'})
  lu.assertItemsEquals(stretched_windows(), {2, 3, 4})
  goto_window(4)
  lu.assertEquals(heights(), {22, 0, 10, 10})
  goto_window(3)
  lu.assertEquals(heights(), {22, 0, 10, 10})
  goto_window(2)
  lu.assertEquals(heights(), {22, 10, 0, 10})
  goto_window(1)
  lu.assertEquals(heights(), {22, 10, 0, 10})
end

-- +-----+------+
-- |     |  2   |
-- |     +------+
-- |  1  |  3   |
-- |     +------+
-- |     | 4 qf |
-- +-----+------+
function test_two_windows_with_left_sidebar_and_with_qf()
  exec({'%bwipe!', 'split', 'copen', 'vsplit', 'wincmd H'})
  lu.assertItemsEquals(stretched_windows(), {2, 3, 4})
  goto_window(4)
  lu.assertEquals(heights(), {22, 0, 10, 10})
  goto_window(3)
  lu.assertEquals(heights(), {22, 0, 10, 10})
  goto_window(2)
  lu.assertEquals(heights(), {22, 10, 0, 10})
  goto_window(1)
  lu.assertEquals(heights(), {22, 10, 0, 10})
end

-- +-----+--------+
-- |     |   2    |
-- |     +-- -----+
-- |  1  | 3 term |
-- |     +--------+
-- |     |  4 qf  |
-- +-----+--------+
function test_conflicts_between_two_fixed_height_windows()
  exec({'%bwipe!', 'split', 'wincmd L', 'rightbelow split', 'term echo 1', 'copen'})
  lu.assertItemsEquals(stretched_windows(), {2, 3, 4})
  goto_window(4)
  lu.assertEquals(heights(), {22, 0, 10, 10})
  goto_window(3)
  lu.assertEquals(heights(), {22, 0, 20, 0}, 'current terminal window is enforced to have height = 20')
  goto_window(2)
  lu.assertEquals(heights(), {22, 1, 10, 9})
  goto_window(1)
  lu.assertEquals(heights(), {22, 0, 10, 10})
end

-- +-----+------+
-- |     |  2   |
-- |     +------+
-- |  1  |  3   |
-- |     +------+
-- |     | 4 qf |
-- +-----+------+
function test_conflicts_between_two_regular_and_one_fixed_height_windows()
  exec({'%bwipe!', 'split', 'wincmd L', 'rightbelow split', 'copen'})
  lu.assertItemsEquals(stretched_windows(), {2, 3, 4})
  goto_window(4)
  lu.assertEquals(heights(), {22, 0, 10, 10})
  goto_window(3)
  lu.assertEquals(heights(), {22, 0, 10, 10})
  goto_window(2)
  lu.assertEquals(heights(), {22, 10, 0, 10})
  goto_window(1)
  lu.assertEquals(heights(), {22, 10, 0, 10})
end

-- +-----+--------+
-- |     | 2 term |
-- |     +--------+
-- |  1  |   3    |
-- |     +--------+
-- |     |  4 qf  |
-- +-----+--------+
function test_conflicts_between_two_fixed_height_windows_and_a_regular_between_them()
  exec({'%bwipe!', 'split', 'wincmd L', 'leftabove split', 'term echo 1', 'copen'})
  lu.assertItemsEquals(stretched_windows(), {2, 3, 4})
  goto_window(4)
  lu.assertEquals(heights(), {22, 10, 0, 10})
  goto_window(3)
  lu.assertEquals(heights(), {22, 9, 1, 10})
  goto_window(2)
  lu.assertEquals(heights(), {22, 20, 0, 0})
  goto_window(1)
  lu.assertEquals(heights(), {22, 10, 0, 10})
end

-- +----------+------+
-- | 1 vars   |      |
-- +----------+   3  |
-- | 2 stack  |      |
-- +----------+------+
-- |    4 output     |
-- +-----------------+
function test_go_debugger_layout()
  vim.g.concertina_win_heights = {
    godebugstacktrace=8,
    godebugoutput=5,
  }
  exec({
    '%bwipe!',
    'topleft    vsplit godebugvariables',  'setf godebugvariables',
    'belowright split  godebugstacktrace', 'setf godebugstacktrace',
    'botright   split  godebugoutput',     'setf godebugoutput',
  })
  lu.assertItemsEquals(stretched_windows(), {4})
  goto_window(4)
  lu.assertEquals(heights(), {7, 8, 16, 5})
  goto_window(3)
  lu.assertEquals(heights(), {7, 8, 16, 5})
  goto_window(2)
  lu.assertEquals(heights(), {7, 8, 16, 5})
  goto_window(1)
  lu.assertEquals(heights(), {7, 8, 16, 5})
end

os.exit(lu.LuaUnit.new():runSuite())
